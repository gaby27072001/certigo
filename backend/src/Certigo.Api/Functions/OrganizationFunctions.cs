using System.Net;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class OrganizationFunctions(
    OrganizationFeatureOptions options,
    IOrganizationService organizations)
{
    [Function("CreateOrganizationV1")]
    public async Task<HttpResponseData> Create(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "v1/organizations")]
        HttpRequestData request,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var body = await request.ReadJsonAsync<CreateOrganizationRequest>(
            context.CancellationToken);
        var result = await organizations.CreateAsync(
            body.Name,
            RequiredIdempotencyKey(request),
            context.CancellationToken);
        return await request.JsonAsync(result, HttpStatusCode.Created, context.CancellationToken);
    }

    [Function("GetOrganizationV1")]
    public async Task<HttpResponseData> Get(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "v1/organizations/{organizationId}")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var result = await organizations.GetAsync(organizationId, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("CreateOrganizationInvitationV1")]
    public async Task<HttpResponseData> Invite(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/invitations")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var body = await request.ReadJsonAsync<CreateOrganizationInvitationRequest>(
            context.CancellationToken);
        var result = await organizations.InviteAsync(
            organizationId,
            body.RecipientEmail,
            body.Role,
            RequiredIdempotencyKey(request),
            context.CancellationToken);
        return await request.JsonAsync(result, HttpStatusCode.Created, context.CancellationToken);
    }

    [Function("AcceptOrganizationInvitationV1")]
    public async Task<HttpResponseData> AcceptInvitation(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organization-invitations/{invitationId}/accept")]
        HttpRequestData request,
        string invitationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var body = await request.ReadJsonAsync<AcceptOrganizationInvitationRequest>(
            context.CancellationToken);
        var result = await organizations.AcceptInvitationAsync(
            body.OrganizationId,
            invitationId,
            body.Token,
            context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("CreateOrganizationTeamV1")]
    public async Task<HttpResponseData> CreateTeam(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "v1/organizations/{organizationId}/teams")]
        HttpRequestData request,
        string organizationId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var body = await request.ReadJsonAsync<CreateOrganizationTeamRequest>(
            context.CancellationToken);
        var result = await organizations.CreateTeamAsync(
            organizationId,
            body.Name,
            RequiredIdempotencyKey(request),
            context.CancellationToken);
        return await request.JsonAsync(result, HttpStatusCode.Created, context.CancellationToken);
    }

    [Function("AddOrganizationTeamMemberV1")]
    public async Task<HttpResponseData> AddTeamMember(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "put",
            Route = "v1/organizations/{organizationId}/teams/{teamId}/members/{personId}")]
        HttpRequestData request,
        string organizationId,
        string teamId,
        string personId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        await organizations.AddTeamMemberAsync(
            organizationId,
            teamId,
            personId,
            context.CancellationToken);
        return request.CreateResponse(HttpStatusCode.NoContent);
    }

    [Function("OffboardOrganizationMemberV1")]
    public async Task<HttpResponseData> Offboard(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "delete",
            Route = "v1/organizations/{organizationId}/memberships/{personId}")]
        HttpRequestData request,
        string organizationId,
        string personId,
        FunctionContext context)
    {
        EnsureAvailable();
        context.GetUser();
        var result = await organizations.OffboardAsync(
            organizationId,
            personId,
            context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    private void EnsureAvailable()
    {
        if (!options.HttpSurfaceEnabled)
        {
            throw new OrganizationFeatureDisabledException();
        }
    }

    private static string RequiredIdempotencyKey(HttpRequestData request)
    {
        if (!request.Headers.TryGetValues("Idempotency-Key", out var values)
            || string.IsNullOrWhiteSpace(values.FirstOrDefault()))
        {
            throw new BadRequestException("Idempotency-Key is required.");
        }
        return values.First();
    }
}
