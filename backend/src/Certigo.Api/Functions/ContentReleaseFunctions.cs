using System.Net;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class ContentReleaseFunctions(IContentReleaseService releases)
{
    [Function("ImportContentRelease")]
    public async Task<HttpResponseData> Import(
        [HttpTrigger(
            AuthorizationLevel.Function,
            "post",
            Route = "admin/content/releases/import")] HttpRequestData request,
        FunctionContext context)
    {
        var body = await request.ReadJsonAsync<ImportContentReleaseRequest>(context.CancellationToken);
        var result = await releases.ImportAsync(body, context.CancellationToken);
        return await request.JsonAsync(
            result,
            result.Imported ? HttpStatusCode.Created : HttpStatusCode.OK,
            context.CancellationToken);
    }

    [Function("PromoteContentRelease")]
    public async Task<HttpResponseData> Promote(
        [HttpTrigger(
            AuthorizationLevel.Function,
            "post",
            Route = "admin/content/releases/{manifestId}/promote")] HttpRequestData request,
        string manifestId,
        FunctionContext context)
    {
        var result = await releases.PromoteAsync(manifestId, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("RollbackContentRelease")]
    public async Task<HttpResponseData> Rollback(
        [HttpTrigger(
            AuthorizationLevel.Function,
            "post",
            Route = "admin/content/releases/{manifestId}/rollback")] HttpRequestData request,
        string manifestId,
        FunctionContext context)
    {
        var body = await request.ReadJsonAsync<RollbackContentReleaseRequest>(context.CancellationToken);
        var result = await releases.RollbackAsync(
            manifestId,
            body.Environment,
            context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("GetActiveContentManifest")]
    public async Task<HttpResponseData> GetActiveManifest(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "content/manifest")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var manifest = await releases.GetActivePublicManifestAsync(context.CancellationToken);
        return await request.JsonAsync(manifest, cancellationToken: context.CancellationToken);
    }
}
