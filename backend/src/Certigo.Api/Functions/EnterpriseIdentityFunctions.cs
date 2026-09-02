using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class EnterpriseIdentityFunctions(EnterpriseIdentityFeatureOptions options)
{
    [Function("GetEnterpriseIdentityMetadataV1")]
    public Task<HttpResponseData> Metadata(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "v1/enterprise-identity/metadata")]
        HttpRequestData request) =>
        Unavailable();

    [Function("EnterpriseDomainsV1")]
    public Task<HttpResponseData> Domains(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            "post",
            Route = "v1/organizations/{organizationId}/enterprise-identity/domains")]
        HttpRequestData request,
        string organizationId) =>
        Unavailable();

    [Function("GetEnterpriseDomainChallengeV1")]
    public Task<HttpResponseData> DomainChallenge(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            "delete",
            Route = "v1/organizations/{organizationId}/enterprise-identity/domain-challenges/{challengeId}")]
        HttpRequestData request,
        string organizationId,
        string challengeId) =>
        Unavailable();

    [Function("VerifyEnterpriseDomainV1")]
    public Task<HttpResponseData> VerifyDomain(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/enterprise-identity/domain-challenges/{challengeId}/verify")]
        HttpRequestData request,
        string organizationId,
        string challengeId) =>
        Unavailable();

    [Function("DeleteEnterpriseDomainV1")]
    public Task<HttpResponseData> DeleteDomain(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "delete",
            Route = "v1/organizations/{organizationId}/enterprise-identity/domains/{domainId}")]
        HttpRequestData request,
        string organizationId,
        string domainId) =>
        Unavailable();

    [Function("EnterpriseFederationV1")]
    public Task<HttpResponseData> Federation(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            "put",
            "delete",
            Route = "v1/organizations/{organizationId}/enterprise-identity/federation")]
        HttpRequestData request,
        string organizationId) =>
        Unavailable();

    [Function("BindEnterpriseFederatedIdentityV1")]
    public Task<HttpResponseData> BindFederatedIdentity(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/enterprise-identity/federation/identity-bindings")]
        HttpRequestData request,
        string organizationId) =>
        Unavailable();

    [Function("CreateEnterpriseScimTokenV1")]
    public Task<HttpResponseData> CreateScimToken(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/enterprise-identity/scim-tokens")]
        HttpRequestData request,
        string organizationId) =>
        Unavailable();

    [Function("RotateEnterpriseScimTokenV1")]
    public Task<HttpResponseData> RotateScimToken(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/enterprise-identity/scim-tokens/{tokenId}/rotate")]
        HttpRequestData request,
        string organizationId,
        string tokenId) =>
        Unavailable();

    [Function("DeleteEnterpriseScimTokenV1")]
    public Task<HttpResponseData> DeleteScimToken(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "delete",
            Route = "v1/organizations/{organizationId}/enterprise-identity/scim-tokens/{tokenId}")]
        HttpRequestData request,
        string organizationId,
        string tokenId) =>
        Unavailable();

    [Function("EnterpriseScimUsersV1")]
    public Task<HttpResponseData> Users(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            "post",
            Route = "v1/organizations/{organizationId}/scim/v2/Users")]
        HttpRequestData request,
        string organizationId) =>
        Unavailable();

    [Function("EnterpriseScimUserV1")]
    public Task<HttpResponseData> User(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            "put",
            "patch",
            "delete",
            Route = "v1/organizations/{organizationId}/scim/v2/Users/{userId}")]
        HttpRequestData request,
        string organizationId,
        string userId) =>
        Unavailable();

    [Function("EnterpriseScimGroupsV1")]
    public Task<HttpResponseData> Groups(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            "post",
            Route = "v1/organizations/{organizationId}/scim/v2/Groups")]
        HttpRequestData request,
        string organizationId) =>
        Unavailable();

    [Function("EnterpriseScimGroupV1")]
    public Task<HttpResponseData> Group(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            "put",
            "patch",
            "delete",
            Route = "v1/organizations/{organizationId}/scim/v2/Groups/{groupId}")]
        HttpRequestData request,
        string organizationId,
        string groupId) =>
        Unavailable();

    private Task<HttpResponseData> Unavailable()
    {
        if (options.Mode == EnterpriseIdentityFeatureMode.Off)
        {
            throw new EnterpriseIdentityFeatureDisabledException();
        }

        throw new InvalidOperationException("No enterprise identity runtime mode is enabled.");
    }
}
