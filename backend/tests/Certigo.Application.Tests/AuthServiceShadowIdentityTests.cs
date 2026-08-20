using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class AuthServiceShadowIdentityTests
{
    [Fact]
    public async Task Successful_register_login_and_refresh_offer_the_exact_local_credential_to_shadow()
    {
        var credentials = new InMemoryUserCredentialRepository();
        var users = new InMemoryUserRepository();
        var shadow = new SpyPersonLinkedIdentityShadowRuntime();
        var service = new AuthService(
            credentials,
            new FakePasswordHasher(),
            new FakeTokenIssuer(),
            users,
            new FakeClock(new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero)),
            new CapturingEmailSender(),
            new AuthEmailOptions(
                "https://verify.test/api/auth/verify-email",
                TimeSpan.FromHours(24)),
            shadow);

        var registered = await service.RegisterAsync(
            new RegisterRequest("shadow@example.com", "password123", "Shadow"));
        await service.LoginAsync(
            new LoginRequest("shadow@example.com", "password123"));
        await service.RefreshAsync(
            new RefreshTokenRequest(registered.RefreshToken));

        shadow.LocalCalls.Should().HaveCount(3);
        shadow.LocalCalls.Should().OnlyContain(call =>
            call.PersonId == registered.Profile.Id
            && call.Credential.Id
                == UserCredentialRecord.CanonicalIdFor("shadow@example.com")
            && call.Credential.UserId == registered.Profile.Id);
    }

    private sealed class SpyPersonLinkedIdentityShadowRuntime
        : IPersonLinkedIdentityShadowRuntime
    {
        public List<(string PersonId, UserCredentialRecord Credential)> LocalCalls { get; } = [];

        public Task<UserProfileDto> TryMirrorProfileAsync(
            IUserRepository profiles,
            UserProfileDto profile,
            LegacyIdentityObservation? observation,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(profile);

        public Task TryMirrorLocalAsync(
            string personId,
            UserCredentialRecord credential,
            CancellationToken cancellationToken = default)
        {
            LocalCalls.Add((personId, credential));
            return Task.CompletedTask;
        }
    }
}
