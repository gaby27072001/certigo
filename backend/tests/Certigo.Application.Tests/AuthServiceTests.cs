using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class InMemoryUserCredentialRepository : IUserCredentialRepository
{
    private readonly Dictionary<string, UserCredentialRecord> _store = new(StringComparer.Ordinal);
    private readonly object _gate = new();
    private long _version;

    public Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            var normalized = AuthRules.NormalizeEmail(email);
            var match = _store.GetValueOrDefault(UserCredentialRecord.IdFor(normalized))
                ?? _store.GetValueOrDefault(
                    UserCredentialRecord.CanonicalIdFor(AuthRules.CanonicalizeEmail(normalized)));
            return Task.FromResult(match);
        }
    }

    public Task<UserCredentialRecord?> FindByCanonicalEmailAsync(string canonicalEmail, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(canonicalEmail))
        {
            return Task.FromResult<UserCredentialRecord?>(null);
        }

        lock (_gate)
        {
            var canonicalId = UserCredentialRecord.CanonicalIdFor(canonicalEmail);
            var match = _store.GetValueOrDefault(canonicalId)
                ?? _store.Values.FirstOrDefault(r => string.Equals(r.CanonicalEmail, canonicalEmail, StringComparison.Ordinal));
            return Task.FromResult<UserCredentialRecord?>(match);
        }
    }

    public Task<UserCredentialRecord> CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            if (_store.ContainsKey(record.Id))
            {
                throw new DuplicateRecordException($"A credential for '{record.Email}' already exists.");
            }

            var stored = record with { ETag = NextETag() };
            _store.Add(record.Id, stored);
            return Task.FromResult(stored);
        }
    }

    public Task UpdateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            if (!_store.TryGetValue(record.Id, out var current)
                || !string.Equals(record.ETag, current.ETag, StringComparison.Ordinal))
            {
                throw new ConcurrencyConflictException("stale credential");
            }

            _store[record.Id] = record with { ETag = NextETag() };
            return Task.CompletedTask;
        }
    }

    public Task<bool> DeletePendingAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            if (!_store.TryGetValue(record.Id, out var current)
                || !current.IsProvisioning
                || !string.Equals(record.ETag, current.ETag, StringComparison.Ordinal))
            {
                return Task.FromResult(false);
            }

            return Task.FromResult(_store.Remove(record.Id));
        }
    }

    public void RemoveByUserId(string userId)
    {
        lock (_gate)
        {
            foreach (var id in _store.Values
                         .Where(record => record.UserId == userId)
                         .Select(record => record.Id)
                         .ToArray())
            {
                _store.Remove(id);
            }
        }
    }

    private string NextETag() => $"\"{Interlocked.Increment(ref _version)}\"";
}

internal sealed class CompleteRegistrationBeforeDeleteCredentialRepository(
    InMemoryUserCredentialRepository inner,
    InMemoryUserRepository users) : IUserCredentialRepository
{
    public Task<UserCredentialRecord?> FindByEmailAsync(
        string email,
        CancellationToken cancellationToken = default) =>
        inner.FindByEmailAsync(email, cancellationToken);

    public Task<UserCredentialRecord?> FindByCanonicalEmailAsync(
        string canonicalEmail,
        CancellationToken cancellationToken = default) =>
        inner.FindByCanonicalEmailAsync(canonicalEmail, cancellationToken);

    public Task<UserCredentialRecord> CreateAsync(
        UserCredentialRecord record,
        CancellationToken cancellationToken = default) =>
        inner.CreateAsync(record, cancellationToken);

    public Task UpdateAsync(
        UserCredentialRecord record,
        CancellationToken cancellationToken = default) =>
        inner.UpdateAsync(record, cancellationToken);

    public async Task<bool> DeletePendingAsync(
        UserCredentialRecord record,
        CancellationToken cancellationToken = default)
    {
        users.Seed(TestContent.NewProfile(record.UserId));
        var current = await inner.FindByCanonicalEmailAsync(
            record.CanonicalEmail!,
            cancellationToken);
        await inner.UpdateAsync(
            current! with
            {
                ProvisioningState = CredentialProvisioningState.Active,
                ProvisioningLeaseExpiresAt = null,
            },
            cancellationToken);
        return await inner.DeletePendingAsync(record, cancellationToken);
    }
}

internal sealed class CoordinatedLegacyLookupCredentialRepository(
    InMemoryUserCredentialRepository inner,
    int participants) : IUserCredentialRepository
{
    private readonly TaskCompletionSource _release =
        new(TaskCreationOptions.RunContinuationsAsynchronously);
    private int _entered;

    public async Task<UserCredentialRecord?> FindByEmailAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        if (Interlocked.Increment(ref _entered) == participants)
        {
            _release.TrySetResult();
        }

        await _release.Task.WaitAsync(cancellationToken);
        return await inner.FindByEmailAsync(email, cancellationToken);
    }

    public Task<UserCredentialRecord?> FindByCanonicalEmailAsync(
        string canonicalEmail,
        CancellationToken cancellationToken = default) =>
        inner.FindByCanonicalEmailAsync(canonicalEmail, cancellationToken);

    public Task<UserCredentialRecord> CreateAsync(
        UserCredentialRecord record,
        CancellationToken cancellationToken = default) =>
        inner.CreateAsync(record, cancellationToken);

    public Task UpdateAsync(
        UserCredentialRecord record,
        CancellationToken cancellationToken = default) =>
        inner.UpdateAsync(record, cancellationToken);

    public Task<bool> DeletePendingAsync(
        UserCredentialRecord record,
        CancellationToken cancellationToken = default) =>
        inner.DeletePendingAsync(record, cancellationToken);
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
    public IssuedTokens Issue(
        string userId,
        string displayName,
        string email,
        DateTimeOffset? authenticatedAt = null)
        => new($"access:{userId}", $"refresh:{userId}|{displayName}|{email}", DateTimeOffset.UtcNow.AddDays(1));

    public RefreshTokenPrincipal? ValidateRefreshToken(string refreshToken)
    {
        if (string.IsNullOrEmpty(refreshToken) || !refreshToken.StartsWith("refresh:", StringComparison.Ordinal))
        {
            return null;
        }

        var parts = refreshToken["refresh:".Length..].Split('|');
        return new RefreshTokenPrincipal(
            parts[0],
            parts.ElementAtOrDefault(1) ?? string.Empty,
            parts.ElementAtOrDefault(2) ?? string.Empty,
            DateTimeOffset.UtcNow);
    }
}

internal sealed class FailingProfileProvisionRepository : IUserRepository
{
    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default) =>
        Task.FromResult<UserProfileDto?>(null);

    public Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default) =>
        Task.FromResult<UserProfileDto?>(null);

    public Task<UserProfileDto> UpsertAsync(
        UserProfileDto profile,
        CancellationToken cancellationToken = default) =>
        Task.FromException<UserProfileDto>(
            new DefinitivePersistenceException(
                "simulated profile provisioning failure",
                new InvalidOperationException("rejected before commit")));
}

internal sealed class CommitThenThrowProfileProvisionRepository(
    InMemoryUserRepository inner,
    Exception? failure = null)
    : IUserRepository
{
    private bool _thrown;

    public Task<UserProfileDto?> GetAsync(
        string userId,
        CancellationToken cancellationToken = default) =>
        inner.GetAsync(userId, cancellationToken);

    public Task<UserProfileDto?> FindByHandleAsync(
        string handle,
        CancellationToken cancellationToken = default) =>
        inner.FindByHandleAsync(handle, cancellationToken);

    public async Task<UserProfileDto> UpsertAsync(
        UserProfileDto profile,
        CancellationToken cancellationToken = default)
    {
        var committed = await inner.UpsertAsync(profile, cancellationToken);
        if (!_thrown)
        {
            _thrown = true;
            throw failure ?? new InvalidOperationException("simulated lost profile response");
        }

        return committed;
    }
}

internal sealed class BlockingProfileProvisionRepository(InMemoryUserRepository inner)
    : IUserRepository
{
    private readonly TaskCompletionSource _entered =
        new(TaskCreationOptions.RunContinuationsAsynchronously);
    private readonly TaskCompletionSource _release =
        new(TaskCreationOptions.RunContinuationsAsynchronously);
    private int _getCalls;

    public int GetCalls => Volatile.Read(ref _getCalls);
    public Task Entered => _entered.Task;

    public void Release() => _release.TrySetResult();

    public async Task<UserProfileDto?> GetAsync(
        string userId,
        CancellationToken cancellationToken = default)
    {
        if (Interlocked.Increment(ref _getCalls) == 1)
        {
            _entered.TrySetResult();
            await _release.Task.WaitAsync(cancellationToken);
        }

        return await inner.GetAsync(userId, cancellationToken);
    }

    public Task<UserProfileDto?> FindByHandleAsync(
        string handle,
        CancellationToken cancellationToken = default) =>
        inner.FindByHandleAsync(handle, cancellationToken);

    public Task<UserProfileDto> UpsertAsync(
        UserProfileDto profile,
        CancellationToken cancellationToken = default) =>
        inner.UpsertAsync(profile, cancellationToken);
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

    [Theory]
    [InlineData("legacy@example.com")]
    [InlineData("LEGACY@Example.COM")]
    public async Task Register_rejects_an_exact_legacy_credential_without_mutating_it(string attemptedEmail)
    {
        var credentials = new InMemoryUserCredentialRepository();
        var createdAt = new DateTimeOffset(2024, 3, 2, 10, 0, 0, TimeSpan.Zero);
        var legacy = await credentials.CreateAsync(new UserCredentialRecord(
            UserCredentialRecord.IdFor("legacy@example.com"),
            "legacy@example.com",
            "legacy-user",
            "Legacy",
            "h:original-password",
            createdAt));
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new InMemoryUserRepository(),
            new FakeClock(new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            TestEmailOptions);

        var act = () => service.RegisterAsync(
            new RegisterRequest(attemptedEmail, "different-password", "Attacker"));

        await act.Should().ThrowAsync<DuplicateRecordException>().WithMessage("*déjà utilisée*");
        var unchanged = await credentials.FindByEmailAsync("legacy@example.com");
        unchanged.Should().BeEquivalentTo(legacy);
        (await credentials.FindByCanonicalEmailAsync("legacy@example.com")).Should().BeNull();
    }

    [Fact]
    public async Task Concurrent_registrations_cannot_replace_an_exact_legacy_credential()
    {
        var innerCredentials = new InMemoryUserCredentialRepository();
        var legacy = await innerCredentials.CreateAsync(new UserCredentialRecord(
            UserCredentialRecord.IdFor("legacy-race@example.com"),
            "legacy-race@example.com",
            "legacy-race-user",
            "Legacy Race",
            "h:original-password",
            new DateTimeOffset(2024, 3, 2, 10, 0, 0, TimeSpan.Zero)));
        var credentials = new CoordinatedLegacyLookupCredentialRepository(
            innerCredentials,
            participants: 3);
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new InMemoryUserRepository(),
            new FakeClock(new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            TestEmailOptions);
        var attemptedEmails = new[]
        {
            "legacy-race@example.com",
            "LEGACY-RACE@EXAMPLE.COM",
            "Legacy-Race@Example.Com",
        };

        var outcomes = await Task.WhenAll(attemptedEmails.Select(async attemptedEmail =>
        {
            try
            {
                await service.RegisterAsync(
                    new RegisterRequest(attemptedEmail, "different-password", "Replacement"));
                return (Exception?)null;
            }
            catch (Exception error)
            {
                return error;
            }
        }));

        outcomes.Should().OnlyContain(error => error is DuplicateRecordException);
        var unchanged = await innerCredentials.FindByEmailAsync("legacy-race@example.com");
        unchanged.Should().BeEquivalentTo(legacy);
        (await innerCredentials.FindByCanonicalEmailAsync("legacy-race@example.com")).Should().BeNull();
    }

    [Fact]
    public async Task Concurrent_canonical_variants_create_one_identity()
    {
        var (service, _, credentials) = Build();
        var requests = new[]
        {
            new RegisterRequest("first.last+one@gmail.com", "password123", "First"),
            new RegisterRequest("firstlast@gmail.com", "password123", "Second"),
        };

        var outcomes = await Task.WhenAll(requests.Select(async request =>
        {
            try
            {
                return (Result: await service.RegisterAsync(request), Error: (Exception?)null);
            }
            catch (Exception error)
            {
                return (Result: (AuthResultDto?)null, Error: error);
            }
        }));

        outcomes.Count(outcome => outcome.Result is not null).Should().Be(1);
        outcomes.Count(outcome => outcome.Error is DuplicateRecordException).Should().Be(1);
        var stored = await credentials.FindByCanonicalEmailAsync("firstlast@gmail.com");
        stored.Should().NotBeNull();
        stored!.IsProvisioning.Should().BeFalse();
    }

    [Fact]
    public async Task Login_rejects_pending_registration_until_profile_is_active()
    {
        var users = new BlockingProfileProvisionRepository(new InMemoryUserRepository());
        var credentials = new InMemoryUserCredentialRepository();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            users,
            new FakeClock(new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            TestEmailOptions);
        var request = new RegisterRequest("race@example.com", "password123", "Race");

        var registration = service.RegisterAsync(request);
        await users.Entered;

        var pendingLogin = () => service.LoginAsync(
            new LoginRequest(request.Email, request.Password));
        await pendingLogin.Should().ThrowAsync<AuthFailedException>()
            .WithMessage("E-mail ou mot de passe incorrect.");
        users.GetCalls.Should().Be(1);

        users.Release();
        await registration;
        var activeLogin = await service.LoginAsync(
            new LoginRequest(request.Email, request.Password));

        activeLogin.AccessToken.Should().StartWith("access:");
        users.GetCalls.Should().Be(2);
    }

    [Fact]
    public async Task Register_rolls_back_pending_identity_when_profile_provisioning_fails()
    {
        var credentials = new InMemoryUserCredentialRepository();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new FailingProfileProvisionRepository(),
            new FakeClock(new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            TestEmailOptions);

        var act = () => service.RegisterAsync(
            new RegisterRequest("rollback@example.com", "password123", "Rollback"));

        await act.Should().ThrowAsync<DefinitivePersistenceException>();
        (await credentials.FindByCanonicalEmailAsync("rollback@example.com")).Should().BeNull();
    }

    [Fact]
    public async Task Register_recovers_when_profile_commits_but_its_response_is_lost()
    {
        var users = new InMemoryUserRepository();
        var credentials = new InMemoryUserCredentialRepository();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new CommitThenThrowProfileProvisionRepository(users),
            new FakeClock(new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            TestEmailOptions);

        var result = await service.RegisterAsync(
            new RegisterRequest("ambiguous@example.com", "password123", "Ambiguous"));

        (await users.GetAsync(result.Profile.Id)).Should().NotBeNull();
        var credential = await credentials.FindByCanonicalEmailAsync("ambiguous@example.com");
        credential.Should().NotBeNull();
        credential!.IsProvisioning.Should().BeFalse();
    }

    [Fact]
    public async Task Register_does_not_delete_reservation_when_profile_committed_concurrently()
    {
        var users = new InMemoryUserRepository();
        var credentials = new InMemoryUserCredentialRepository();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new CommitThenThrowProfileProvisionRepository(
                users,
                new DefinitivePersistenceException(
                    "simulated rejected response",
                    new InvalidOperationException("race"))),
            new FakeClock(new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            TestEmailOptions);

        var result = await service.RegisterAsync(
            new RegisterRequest("rollback-race@example.com", "password123", "Race"));

        (await users.GetAsync(result.Profile.Id)).Should().NotBeNull();
        var credential = await credentials.FindByCanonicalEmailAsync(
            "rollback-race@example.com");
        credential.Should().NotBeNull();
        credential!.IsProvisioning.Should().BeFalse();
    }

    [Fact]
    public async Task Register_rollback_etag_cannot_delete_a_concurrently_completed_identity()
    {
        var users = new InMemoryUserRepository();
        var innerCredentials = new InMemoryUserCredentialRepository();
        var credentials = new CompleteRegistrationBeforeDeleteCredentialRepository(
            innerCredentials,
            users);
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new FailingProfileProvisionRepository(),
            new FakeClock(new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            TestEmailOptions);

        var act = () => service.RegisterAsync(
            new RegisterRequest("rollback-etag@example.com", "password123", "Race"));

        await act.Should().ThrowAsync<DefinitivePersistenceException>();
        var credential = await innerCredentials.FindByCanonicalEmailAsync(
            "rollback-etag@example.com");
        credential.Should().NotBeNull();
        credential!.IsProvisioning.Should().BeFalse();
        (await users.GetAsync(credential.UserId)).Should().NotBeNull();
    }

    [Fact]
    public async Task Register_recovers_an_expired_pending_identity()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        var credentials = new InMemoryUserCredentialRepository();
        await credentials.CreateAsync(new UserCredentialRecord(
            UserCredentialRecord.CanonicalIdFor("recover@example.com"),
            "recover@example.com",
            "reserved-user",
            "Recover",
            "h:password123",
            now.AddMinutes(-10),
            CanonicalEmail: "recover@example.com",
            EmailVerified: false,
            ProvisioningState: CredentialProvisioningState.Pending,
            ProvisioningLeaseExpiresAt: now.AddMinutes(-5)));
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            new InMemoryUserRepository(),
            new FakeClock(now),
            new CapturingEmailSender(),
            TestEmailOptions);

        var result = await service.RegisterAsync(
            new RegisterRequest("recover@example.com", "password123", "Recovered"));

        result.Profile.Id.Should().Be("reserved-user");
        var recovered = await credentials.FindByCanonicalEmailAsync("recover@example.com");
        recovered!.IsProvisioning.Should().BeFalse();
        recovered.ProvisioningLeaseExpiresAt.Should().BeNull();
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

    [Fact]
    public async Task Refresh_rejects_a_previously_issued_token_after_credentials_are_deleted()
    {
        var (service, _, credentials) = Build();
        var registered = await service.RegisterAsync(
            new RegisterRequest("deleted@example.com", "password123", "Deleted"));
        credentials.RemoveByUserId(registered.Profile.Id);

        var act = () => service.RefreshAsync(new RefreshTokenRequest(registered.RefreshToken));

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
