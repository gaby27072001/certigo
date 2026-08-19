using System.Net;
using Azure.Core;
using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Infrastructure.Identity;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class GraphExternalIdentityDeletionTests
{
    [Fact]
    public async Task Delete_uses_managed_identity_token_and_escaped_subject()
    {
        var handler = new CapturingHandler(HttpStatusCode.OK, HttpStatusCode.NoContent);
        var service = new GraphExternalIdentityDeletion(
            new HttpClient(handler) { BaseAddress = new Uri("https://graph.microsoft.com/") },
            new FixedTokenCredential());

        await service.DeleteAsync("user/id");

        handler.Requests.Should().HaveCount(2);
        handler.Requests[0].Method.Should().Be(HttpMethod.Post);
        handler.Requests[0].RequestUri!.AbsoluteUri.Should()
            .Be("https://graph.microsoft.com/v1.0/users/user%2Fid/revokeSignInSessions");
        handler.Requests[1].Method.Should().Be(HttpMethod.Delete);
        handler.Requests[1].RequestUri!.AbsoluteUri.Should()
            .Be("https://graph.microsoft.com/v1.0/users/user%2Fid");
        handler.AuthorizationScheme.Should().Be("Bearer");
        handler.AuthorizationParameter.Should().Be("graph-token");
    }

    [Fact]
    public async Task Delete_is_idempotent_when_identity_is_already_absent()
    {
        var service = new GraphExternalIdentityDeletion(
            new HttpClient(new CapturingHandler(HttpStatusCode.NotFound, HttpStatusCode.NotFound))
            {
                BaseAddress = new Uri("https://graph.microsoft.com/"),
            },
            new FixedTokenCredential());

        var act = () => service.DeleteAsync("missing-user");

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task Delete_surfaces_permission_failure_as_retryable_code_without_response_body()
    {
        var service = new GraphExternalIdentityDeletion(
            new HttpClient(new CapturingHandler(HttpStatusCode.OK, HttpStatusCode.Forbidden))
            {
                BaseAddress = new Uri("https://graph.microsoft.com/"),
            },
            new FixedTokenCredential());

        var exception = await Assert.ThrowsAsync<AccountDeletionStepException>(
            () => service.DeleteAsync("user-1"));

        exception.FailureCode.Should().Be("external-identity-permission-denied");
        exception.Message.Should().NotContain("user-1");
    }

    [Fact]
    public async Task Delete_requires_session_revocation_permission_before_deleting_identity()
    {
        var handler = new CapturingHandler(HttpStatusCode.Forbidden);
        var service = new GraphExternalIdentityDeletion(
            new HttpClient(handler) { BaseAddress = new Uri("https://graph.microsoft.com/") },
            new FixedTokenCredential());

        var exception = await Assert.ThrowsAsync<AccountDeletionStepException>(
            () => service.DeleteAsync("user-1"));

        exception.FailureCode.Should().Be("external-session-revocation-permission-denied");
        handler.Requests.Should().ContainSingle();
        handler.Requests[0].Method.Should().Be(HttpMethod.Post);
    }

    [Fact]
    public async Task Missing_cross_tenant_configuration_fails_pending_instead_of_claiming_success()
    {
        var service = new UnavailableExternalIdentityDeletion();

        var exception = await Assert.ThrowsAsync<AccountDeletionStepException>(
            () => service.DeleteAsync("external-user"));

        exception.FailureCode.Should().Be("external-identity-configuration-missing");
    }

    private sealed class FixedTokenCredential : TokenCredential
    {
        private static readonly AccessToken Token =
            new("graph-token", DateTimeOffset.UtcNow.AddMinutes(5));

        public override AccessToken GetToken(
            TokenRequestContext requestContext,
            CancellationToken cancellationToken)
            => Token;

        public override ValueTask<AccessToken> GetTokenAsync(
            TokenRequestContext requestContext,
            CancellationToken cancellationToken)
            => ValueTask.FromResult(Token);
    }

    private sealed class CapturingHandler(params HttpStatusCode[] statusCodes) : HttpMessageHandler
    {
        private int _call;
        public List<HttpRequestMessage> Requests { get; } = [];
        public string? AuthorizationScheme { get; private set; }
        public string? AuthorizationParameter { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            Requests.Add(request);
            AuthorizationScheme = request.Headers.Authorization?.Scheme;
            AuthorizationParameter = request.Headers.Authorization?.Parameter;
            var index = Math.Min(_call++, statusCodes.Length - 1);
            return Task.FromResult(new HttpResponseMessage(statusCodes[index]));
        }
    }
}
