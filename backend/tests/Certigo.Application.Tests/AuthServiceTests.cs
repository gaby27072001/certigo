using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class InMemoryUserCredentialRepository : IUserCredentialRepository
{
    private readonly Dictionary<string, UserCredentialRecord> _store = new(StringComparer.Ordinal);

    public Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(UserCredentialRecord.IdFor(email.Trim().ToLowerInvariant())));

    public Task<UserCredentialRecord?> FindByCanonicalEmailAsync(string canonicalEmail, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(canonicalEmail))
        {
            return Task.FromResult<UserCredentialRecord?>(null);
        }

        var match = _store.Values.FirstOrDefault(r => string.Equals(r.CanonicalEmail, canonicalEmail, StringComparison.Ordinal));
        return Task.FromResult<UserCredentialRecord?>(match);
    }

    public Task CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        if (!_store.TryAdd(record.Id, record))
        {
            throw new DuplicateRecordException($"A credential for '{record.Email}' already exists.");
        }

        return Task.CompletedTask;
    }

    public Task UpdateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        _store[record.Id] = record;
        return Task.CompletedTask;
    }
}

/// Captures the emails an <see cref="AuthService"/> would send so verification
/// tests can pull the confirmation link out of the outbox.
internal sealed class CapturingEmailSender : IEmailSender
{
    public List<EmailMessage> Sent { get; } = new();

    public EmailMessage? Last => Sent.Count == 0 ? null : Sent[^1];

    public Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        Sent.Add(message);
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
    [InlineData("        ", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void IsValidPassword_enforces_minimum_length(string? password, bool expected)
        => AuthRules.IsValidPassword(password).Should().Be(expected);

    [Fact]
    public void NormalizeEmail_trims_and_lowercases()
        => AuthRules.NormalizeEmail("  Foo@Bar.COM ").Should().Be("foo@bar.com");

    [Theory]
    [InlineData("gabriel.chambaud@gmail.com", "gabrielchambaud@gmail.com")]
    [InlineData("Gabriel.Chambaud+news@googlemail.com", "gabrielchambaud@gmail.com")]
    [InlineData("g.a.b@gmail.com", "gab@gmail.com")]
    [InlineData("user+tag@outlook.com", "user+tag@outlook.com")]
    [InlineData("plain.dot@example.com", "plain.dot@example.com")]
    public void CanonicalizeEmail_reduces_only_gmail_variants(string input, string expected)
        => AuthRules.CanonicalizeEmail(input).Should().Be(expected);
}

public sealed class AuthServiceTests
{
    private static readonly AuthEmailOptions TestEmailOptions =
        new("https://verify.test/api/auth/verify-email", TimeSpan.FromHours(24));

    private static (AuthService Service, InMemoryUserRepository Users, InMemoryUserCredentialRepository Credentials) Build()
    {
        var users = new InMemoryUserRepository();
        var credentials = new InMemoryUserCredentialRepository();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            users,
            new FakeClock(DateTimeOffset.UtcNow),
            new CapturingEmailSender(),
            TestEmailOptions);
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

    private static (AuthService Service, FakeClock Clock) BuildTimed()
    {
        var clock = new FakeClock(DateTimeOffset.UtcNow);
        var service = new AuthService(
            new InMemoryUserCredentialRepository(),
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new InMemoryUserRepository(),
            clock,
            new CapturingEmailSender(),
            TestEmailOptions);
        return (service, clock);
    }

    private static (AuthService Service, InMemoryUserCredentialRepository Credentials, CapturingEmailSender Email) BuildWithEmail()
    {
        var credentials = new InMemoryUserCredentialRepository();
        var email = new CapturingEmailSender();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new InMemoryUserRepository(),
            new FakeClock(DateTimeOffset.UtcNow),
            email,
            TestEmailOptions);
        return (service, credentials, email);
    }

    private static string ExtractVerificationCode(CapturingEmailSender email)
    {
        var body = email.Last!.PlainTextBody;
        var marker = body.IndexOf("code=", StringComparison.Ordinal);
        marker.Should().BeGreaterThan(-1);
        var raw = body[(marker + "code=".Length)..];
        var end = raw.IndexOfAny(new[] { ' ', '\r', '\n', '\t' });
        if (end >= 0)
        {
            raw = raw[..end];
        }

        return Uri.UnescapeDataString(raw);
    }

    [Fact]
    public async Task Login_locks_the_account_after_five_failed_attempts()
    {
        var (service, _) = BuildTimed();
        await service.RegisterAsync(new RegisterRequest("lock@example.com", "password123", null));

        for (var i = 0; i < 5; i++)
        {
            var bad = async () => await service.LoginAsync(new LoginRequest("lock@example.com", "wrong-password"));
            await bad.Should().ThrowAsync<AuthFailedException>();
        }

        // Even the CORRECT password is now refused while the lockout window holds.
        var locked = async () => await service.LoginAsync(new LoginRequest("lock@example.com", "password123"));
        await locked.Should().ThrowAsync<RateLimitedException>().WithMessage("*Trop de tentatives*");
    }

    [Fact]
    public async Task Lockout_expires_after_the_window_then_login_succeeds()
    {
        var (service, clock) = BuildTimed();
        await service.RegisterAsync(new RegisterRequest("expire@example.com", "password123", null));

        for (var i = 0; i < 5; i++)
        {
            var bad = async () => await service.LoginAsync(new LoginRequest("expire@example.com", "wrong-password"));
            await bad.Should().ThrowAsync<AuthFailedException>();
        }

        // Advance past the 15-minute lockout window.
        clock.UtcNow = clock.UtcNow.AddMinutes(16);

        var result = await service.LoginAsync(new LoginRequest("expire@example.com", "password123"));
        result.AccessToken.Should().StartWith("access:");
    }

    [Fact]
    public async Task A_successful_login_resets_the_failure_counter()
    {
        var (service, _) = BuildTimed();
        await service.RegisterAsync(new RegisterRequest("reset@example.com", "password123", null));

        // Four failures (below the threshold), then a success resets the counter.
        for (var i = 0; i < 4; i++)
        {
            var bad = async () => await service.LoginAsync(new LoginRequest("reset@example.com", "wrong-password"));
            await bad.Should().ThrowAsync<AuthFailedException>();
        }

        await service.LoginAsync(new LoginRequest("reset@example.com", "password123"));

        // Four more failures must still NOT lock (the counter restarted from zero).
        for (var i = 0; i < 4; i++)
        {
            var bad = async () => await service.LoginAsync(new LoginRequest("reset@example.com", "wrong-password"));
            await bad.Should().ThrowAsync<AuthFailedException>();
        }
    }

    [Fact]
    public async Task Register_marks_the_new_account_unverified_and_sends_a_confirmation_email()
    {
        var (service, _, email) = BuildWithEmail();

        var result = await service.RegisterAsync(new RegisterRequest("newbie@example.com", "password123", null));

        result.EmailVerified.Should().BeFalse();
        email.Sent.Should().ContainSingle();
        email.Last!.ToEmail.Should().Be("newbie@example.com");
        email.Last.PlainTextBody.Should().Contain("code=");
    }

    [Fact]
    public async Task Login_is_not_blocked_while_the_email_is_unverified()
    {
        var (service, _, _) = BuildWithEmail();
        await service.RegisterAsync(new RegisterRequest("pending@example.com", "password123", null));

        var login = await service.LoginAsync(new LoginRequest("pending@example.com", "password123"));

        login.AccessToken.Should().StartWith("access:");
        login.EmailVerified.Should().BeFalse();
    }

    [Fact]
    public async Task Verify_confirms_the_account_and_a_later_login_reports_verified()
    {
        var (service, _, email) = BuildWithEmail();
        await service.RegisterAsync(new RegisterRequest("confirm@example.com", "password123", null));
        var code = ExtractVerificationCode(email);

        var verify = await service.VerifyAsync(code);

        verify.Success.Should().BeTrue();
        var login = await service.LoginAsync(new LoginRequest("confirm@example.com", "password123"));
        login.EmailVerified.Should().BeTrue();
    }

    [Fact]
    public async Task Verify_rejects_a_tampered_code()
    {
        var (service, _, _) = BuildWithEmail();
        await service.RegisterAsync(new RegisterRequest("tamper@example.com", "password123", null));

        var verify = await service.VerifyAsync("not-a-real-code");

        verify.Success.Should().BeFalse();
    }

    [Theory]
    [InlineData("gabriel.chambaud@gmail.com", "gabrielchambaud@gmail.com")]
    [InlineData("gabriel.chambaud@gmail.com", "gabriel.chambaud+news@gmail.com")]
    [InlineData("gabriel.chambaud@gmail.com", "Gabriel.Chambaud@googlemail.com")]
    public async Task Register_rejects_a_gmail_variant_of_an_existing_account(string first, string second)
    {
        var (service, _, _) = BuildWithEmail();
        await service.RegisterAsync(new RegisterRequest(first, "password123", null));

        var act = async () => await service.RegisterAsync(new RegisterRequest(second, "password123", null));

        await act.Should().ThrowAsync<DuplicateRecordException>().WithMessage("*déjà utilisée*");
    }

    [Fact]
    public async Task Login_matches_a_gmail_dot_variant_of_the_registered_address()
    {
        var (service, _, _) = BuildWithEmail();
        await service.RegisterAsync(new RegisterRequest("gabriel.chambaud@gmail.com", "password123", "Gab"));

        // A learner who typed their own address without the dots still gets in.
        var login = await service.LoginAsync(new LoginRequest("gabrielchambaud@gmail.com", "password123"));

        login.Profile.DisplayName.Should().Be("Gab");
    }
}
