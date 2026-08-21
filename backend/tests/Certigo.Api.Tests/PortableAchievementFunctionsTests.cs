using System.Net;
using Certigo.Api.Functions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.PortableAchievements;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class PortableAchievementFunctionsTests
{
    [Fact]
    public async Task Issue_derives_owner_from_authentication_and_never_accepts_owner_in_contract()
    {
        var service = new RecordingPortableAchievementService();
        var function = new PortableAchievementFunctions(service);
        var context = TestFunctionContext.Authenticated("person-1");
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/me/portable-achievements",
            new IssuePortableAchievementRequest("request-1", "completion-1"));

        var response = await function.Issue(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        service.LastIssue.Should().NotBeNull();
        typeof(IssuePortableAchievementRequest).GetProperties()
            .Select(property => property.Name)
            .Should().NotContain([
                "UserId",
                "OwnerId",
                "SubjectId",
                "Kind",
                "AchievementId",
                "ReleaseId",
                "PublicManifestId",
                "CompletedAt",
            ]);
    }

    [Fact]
    public async Task Feature_off_exception_propagates_for_middleware_to_hide_dormant_surface()
    {
        var function = new PortableAchievementFunctions(new DisabledPortableAchievementService());
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/me/portable-achievements/proof-1");

        var act = () => function.Get(request, "proof-1", context);

        await act.Should().ThrowAsync<PortableAchievementsDisabledException>();
    }

    private sealed class RecordingPortableAchievementService : IPortableAchievementService
    {
        public IssuePortableAchievementRequest? LastIssue { get; private set; }

        public Task<IssuePortableAchievementResult> IssueAsync(
            IssuePortableAchievementRequest request,
            CancellationToken cancellationToken = default)
        {
            LastIssue = request;
            return Task.FromResult(new IssuePortableAchievementResult(Proof(), false));
        }

        public Task<PortableAchievementView> GetAsync(
            string proofId,
            CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<VerifyPortableAchievementResult> VerifyAsync(
            VerifyPortableAchievementRequest request,
            CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();
    }

    private sealed class DisabledPortableAchievementService : IPortableAchievementService
    {
        public Task<IssuePortableAchievementResult> IssueAsync(
            IssuePortableAchievementRequest request,
            CancellationToken cancellationToken = default) =>
            throw new PortableAchievementsDisabledException();

        public Task<PortableAchievementView> GetAsync(
            string proofId,
            CancellationToken cancellationToken = default) =>
            throw new PortableAchievementsDisabledException();

        public Task<VerifyPortableAchievementResult> VerifyAsync(
            VerifyPortableAchievementRequest request,
            CancellationToken cancellationToken = default) =>
            throw new PortableAchievementsDisabledException();
    }

    private static PortableAchievementProof Proof() =>
        new(
            PortableAchievementContracts.CredentialV1,
            "proof-1",
            PortableAchievementContracts.SubjectType,
            "person-1",
            PortableAchievementKind.Badge,
            "badge-1",
            "sha256:evidence",
            "sha256:release",
            "sha256:manifest",
            new DateTimeOffset(2026, 8, 21, 8, 0, 0, TimeSpan.Zero),
            new DateTimeOffset(2026, 8, 21, 9, 0, 0, TimeSpan.Zero),
            "nonce",
            PortableAchievementContracts.IssuerType,
            "certigo",
            new PortableSigningKeyReference("key", 1, "test"),
            "signature");
}
