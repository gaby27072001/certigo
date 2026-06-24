using FluentAssertions;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;
using Xunit;

namespace Microlingo.Application.Tests;

internal sealed class InMemoryUserCredentialRepository : IUserCredentialRepository
{
    private readonly Dictionary<string, UserCredentialRecord> _store = new(StringComparer.Ordinal);

    public Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(UserCredentialRecord.IdFor(email.Trim().ToLowerInvariant())));

    public Task CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        if (!_store.TryAdd(record.Id, record))
        {
            throw new DuplicateRecordException($"A credential for '{record.Email}' already exists.");
        }

        return Task.CompletedTask;
    }
}

/// Deterministic, in-memory password hasher for fast service tests; the real
/// PBKDF2 hasher is exercised in the Infrastructure test suite.
internal sealed class FakePasswordHasher : IPasswordHasher
{
    public string Hash(string password) => "h:" + password;
    public bool Verify(string password, string hash) => string.Equals(hash, "h:" + password, StringComparison.Ordinal);
}

internal sealed class FakeTokenIssuer : ITokenIssuer
{
    public IssuedTokens Issue(string userId, string displayName, string email)
        => new($"access:{userId}", $"refresh:{userId}|{displayName}|{email}", DateTimeOffset.UtcNow.AddDays(1));

    public RefreshTokenPrincipal? ValidateRefreshToken(string refreshToken)
    {
        if (string.IsNullOrEmpty(refreshToken) || !refreshToken.StartsWith("refresh:", StringComparison.Ordinal))
        {
            return null;
        }

        var parts = refreshToken["refresh:".Length..].Split('|');
        return new RefreshTokenPrincipal(parts[0], parts.ElementAtOrDefault(1) ?? string.Empty, parts.ElementAtOrDefault(2) ?? string.Empty);
    }
}

public sealed class AuthRulesTests
{
    [Theory]
    [InlineData("user@example.com", true)]
    [InlineData("  User@Example.Com  ", true)]
    [InlineData("a@b.co", true)]
    [InlineData("no-at-sign", false)]
    [InlineData("@example.com", false)]
    [InlineData("user@", false)]
    [InlineData("user@domain", false)]
    [InlineData("", false)]
    public void IsValidEmail_classifies_inputs(string email, bool expected)
        => AuthRules.IsValidEmail(email).Should().Be(expected);

    [Theory]
    [InlineData("password123", true)]
    [InlineData("12345678", true)]
    [InlineData("short", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void IsValidPassword_enforces_minimum_length(string? password, bool expected)
        => AuthRules.IsValidPassword(password).Should().Be(expected);

    [Fact]
    public void NormalizeEmail_trims_and_lowercases()
        => AuthRules.NormalizeEmail("  Foo@Bar.COM ").Should().Be("foo@bar.com");
}

public sealed class AuthServiceTests
{
    private static (AuthService Service, InMemoryUserRepository Users, InMemoryUserCredentialRepository Credentials) Build()
    {
        var users = new InMemoryUserRepository();
        var credentials = new InMemoryUserCredentialRepository();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            users,
            new FakeClock(DateTimeOffset.UtcNow));
        return (service, users, credentials);
    }

    [Fact]
    public async Task Register_provisions_profile_and_returns_tokens()
    {
        var (service, users, credentials) = Build();

        var result = await service.RegisterAsync(new RegisterRequest("User@Example.com", "password123", "Alice"));

        result.Profile.DisplayName.Should().Be("Alice");
        result.AccessToken.Should().StartWith("access:");
        result.RefreshToken.Should().StartWith("refresh:");
        (await users.GetAsync(result.Profile.Id)).Should().NotBeNull();
        (await credentials.FindByEmailAsync("user@example.com")).Should().NotBeNull();
    }

    [Fact]
    public async Task Register_derives_display_name_from_email_when_absent()
    {
        var (service, _, _) = Build();

        var result = await service.RegisterAsync(new RegisterRequest("bob@example.com", "password123", null));

        result.Profile.DisplayName.Should().Be("bob");
    }

    [Fact]
    public async Task Register_rejects_a_duplicate_email_case_insensitively()
    {
        var (service, _, _) = Build();
        await service.RegisterAsync(new RegisterRequest("dup@example.com", "password123", null));

        var act = async () => await service.RegisterAsync(new RegisterRequest("DUP@Example.com", "password123", null));

        await act.Should().ThrowAsync<DuplicateRecordException>().WithMessage("*déjà utilisée*");
    }

    [Fact]
    public async Task Register_rejects_an_invalid_email()
    {
        var (service, _, _) = Build();

        var act = async () => await service.RegisterAsync(new RegisterRequest("not-an-email", "password123", null));

        await act.Should().ThrowAsync<AuthFailedException>().WithMessage("*Adresse e-mail*");
    }

    [Fact]
    public async Task Register_rejects_a_short_password()
    {
        var (service, _, _) = Build();

        var act = async () => await service.RegisterAsync(new RegisterRequest("a@example.com", "short", null));

        await act.Should().ThrowAsync<AuthFailedException>().WithMessage("*8 caractères*");
    }

    [Fact]
    public async Task Login_succeeds_with_the_registered_password()
    {
        var (service, _, _) = Build();
        await service.RegisterAsync(new RegisterRequest("carol@example.com", "password123", "Carol"));

        var login = await service.LoginAsync(new LoginRequest("Carol@Example.com", "password123"));

        login.Profile.DisplayName.Should().Be("Carol");
        login.AccessToken.Should().StartWith("access:");
    }

    [Fact]
    public async Task Login_rejects_a_wrong_password()
    {
        var (service, _, _) = Build();
        await service.RegisterAsync(new RegisterRequest("dan@example.com", "password123", null));

        var act = async () => await service.LoginAsync(new LoginRequest("dan@example.com", "wrong-password"));

        await act.Should().ThrowAsync<AuthFailedException>().WithMessage("*incorrect*");
    }

    [Fact]
    public async Task Login_rejects_an_unknown_email()
    {
        var (service, _, _) = Build();

        var act = async () => await service.LoginAsync(new LoginRequest("ghost@example.com", "password123"));

        await act.Should().ThrowAsync<AuthFailedException>();
    }

    [Fact]
    public async Task Refresh_issues_new_tokens_for_a_valid_refresh_token()
    {
        var (service, _, _) = Build();
        var registered = await service.RegisterAsync(new RegisterRequest("eve@example.com", "password123", "Eve"));

        var refreshed = await service.RefreshAsync(new RefreshTokenRequest(registered.RefreshToken));

        refreshed.Profile.Id.Should().Be(registered.Profile.Id);
        refreshed.AccessToken.Should().StartWith("access:");
    }

    [Fact]
    public async Task Refresh_rejects_an_invalid_token()
    {
        var (service, _, _) = Build();

        var act = async () => await service.RefreshAsync(new RefreshTokenRequest("garbage"));

        await act.Should().ThrowAsync<AuthFailedException>().WithMessage("*Session expirée*");
    }
}
