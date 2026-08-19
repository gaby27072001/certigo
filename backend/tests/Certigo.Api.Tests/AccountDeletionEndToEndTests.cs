using System.Net;
using System.Security.Claims;
using FluentAssertions;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Auth;
using Certigo.Api.Functions;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class AccountDeletionEndToEndTests
{
    [Fact]
    public async Task Validated_proof_flows_through_middleware_api_service_and_durable_guard()
    {
        var now = DateTimeOffset.FromUnixTimeSeconds(DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        var bearerPrincipal = TestPrincipal.With(oid: "user-1", name: "Learner");
        var proofPrincipal = TestPrincipal.With(oid: "user-1", name: "Learner");
        ((ClaimsIdentity)proofPrincipal.Identity!).AddClaim(
            new Claim("auth_time", now.ToUnixTimeSeconds().ToString()));
        var tokenValidator = new EndToEndTokenValidator(bearerPrincipal, proofPrincipal);
        var repository = new EndToEndDeletionRepository();
        var guard = new AccountDeletionAccessGuard(repository);
        var service = new AccountDeletionService(
            new FunctionUserContext(),
            repository,
            new NoopExternalIdentityDeletion(),
            new NoopDeletionAudit(),
            new FixedClock(now));
        var function = new AccountDeletionFunctions(service);
        var middleware = new JwtAuthMiddleware(
            tokenValidator,
            guard,
            new EndToEndProofValidator(proofPrincipal));
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: "/api/account/deletion",
            headers: new Dictionary<string, string>
            {
                ["Authorization"] = "Bearer access",
                ["X-Certigo-Reauthentication"] = "fresh-proof",
            });
        HttpResponseData? response = null;

        await middleware.Invoke(invocation.Context, async context =>
        {
            response = await function.Request(invocation.Request!, context);
        });

        response!.StatusCode.Should().Be(HttpStatusCode.OK);
        repository.Calls.Should().Equal(
            "social",
            "learning",
            "economy",
            "profile",
            "social",
            "social",
            "learning",
            "economy",
            "profile",
            "social",
            "credentials",
            "credentials");
        repository.Record!.Status.Should().Be(AccountDeletionRecordStatus.Completed);
        repository.Record.SubjectUserId.Should().BeNull();

        var blocked = FunctionTestHarness.CreateHttp(
            method: "GET",
            path: "/api/me",
            headers: new Dictionary<string, string>
            {
                ["Authorization"] = "Bearer access",
            });
        var nextCalled = false;
        await middleware.Invoke(blocked.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeFalse();
        blocked.Response!.StatusCode.Should().Be((HttpStatusCode)423);
    }

    private sealed class FixedClock(DateTimeOffset now) : IClock
    {
        public DateTimeOffset UtcNow { get; } = now;
    }

    private sealed class NoopDeletionAudit : IAccountDeletionAudit
    {
        public void Record(AccountDeletionAuditEvent auditEvent) { }
    }

    private sealed class NoopExternalIdentityDeletion : IExternalIdentityDeletion
    {
        public Task DeleteAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }

    private sealed class EndToEndTokenValidator(
        ClaimsPrincipal bearerPrincipal,
        ClaimsPrincipal proofPrincipal) : ITokenValidator
    {
        public Task<TokenValidationResult> TryValidateAsync(
            string token,
            CancellationToken cancellationToken = default)
            => Task.FromResult(token switch
            {
                "access" => new TokenValidationResult(true, bearerPrincipal, "user-1"),
                "fresh-proof" => new TokenValidationResult(true, proofPrincipal, "user-1"),
                _ => new TokenValidationResult(false, null, null),
            });
    }

    private sealed class EndToEndProofValidator(ClaimsPrincipal principal)
        : IReauthenticationProofValidator
    {
        public Task<TokenValidationResult> TryValidateAsync(
            string token,
            CancellationToken cancellationToken = default)
            => Task.FromResult(token == "fresh-proof"
                ? new TokenValidationResult(true, principal, "user-1")
                : new TokenValidationResult(false, null, null));
    }

    private sealed class EndToEndDeletionRepository : IAccountDeletionRepository
    {
        public AccountDeletionRecord? Record { get; private set; }
        public List<string> Calls { get; } = [];

        public Task<AccountDeletionRecord?> GetAsync(
            string subjectHash,
            CancellationToken cancellationToken = default)
            => Task.FromResult(Record);

        public Task<AccountDeletionRecord> GetOrCreateAsync(
            AccountDeletionRecord record,
            CancellationToken cancellationToken = default)
        {
            Record ??= record;
            return Task.FromResult(Record);
        }

        public Task<AccountIdentityKind> ResolveIdentityKindAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(AccountIdentityKind.Local);

        public Task<AccountDeletionRecord> MarkStepCompletedAsync(
            string subjectHash,
            string step,
            DateTimeOffset updatedAt,
            CancellationToken cancellationToken = default)
        {
            Record = Record! with
            {
                CompletedSteps = Record.CompletedSteps.Append(step).ToArray(),
                UpdatedAt = updatedAt,
            };
            return Task.FromResult(Record);
        }

        public Task<AccountDeletionRecord> MarkFailureAsync(
            string subjectHash,
            string failureCode,
            DateTimeOffset updatedAt,
            DateTimeOffset nextRetryAt,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException("The end-to-end happy path must not fail.");

        public Task<AccountDeletionRecord> MarkCompletedAsync(
            string subjectHash,
            DateTimeOffset completedAt,
            int retentionSeconds,
            CancellationToken cancellationToken = default)
        {
            Record = Record! with
            {
                SubjectUserId = null,
                Status = AccountDeletionRecordStatus.Completed,
                CompletedAt = completedAt,
                UpdatedAt = completedAt,
                Ttl = retentionSeconds,
            };
            return Task.FromResult(Record);
        }

        public async Task ReconcileDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
        {
            await DeleteSocialDataAsync(subjectUserId, cancellationToken);
            await DeleteLearningDataAsync(subjectUserId, cancellationToken);
            await DeleteEconomyDataAsync(subjectUserId, cancellationToken);
            await DeleteProfileAsync(subjectUserId, cancellationToken);
            await DeleteSocialDataAsync(subjectUserId, cancellationToken);
            await DeleteCredentialsAsync(subjectUserId, cancellationToken);
        }

        public Task DeleteSocialDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => RecordCall("social");

        public Task DeleteLearningDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => RecordCall("learning");

        public Task DeleteEconomyDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => RecordCall("economy");

        public Task DeleteProfileAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => RecordCall("profile");

        public Task DeleteCredentialsAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => RecordCall("credentials");

        private Task RecordCall(string call)
        {
            Calls.Add(call);
            return Task.CompletedTask;
        }
    }
}
