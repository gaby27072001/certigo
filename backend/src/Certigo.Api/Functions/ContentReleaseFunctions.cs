using System.Net;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class ContentReleaseFunctions(IContentReleaseService releases)
{
    public const string OperatorRole = "ContentReleaseOperator";
    private const long MaxImportRequestBytes = 70_000_000;

    [Function("ImportContentRelease")]
    public async Task<HttpResponseData> Import(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "ops/content/releases/import")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUserInRole(OperatorRole);
        if (request.Headers.TryGetValues("Content-Length", out var values)
            && long.TryParse(values.FirstOrDefault(), out var contentLength)
            && contentLength > MaxImportRequestBytes)
        {
            throw new BadRequestException("Content release import body is too large.");
        }
        var payload = await request.ReadJsonAsync<ContentReleaseImportRequest>(
            MaxImportRequestBytes,
            context.CancellationToken);
        var result = await releases.ImportAsync(payload, context.CancellationToken);
        return await request.JsonAsync(
            result,
            result.AlreadyImported ? HttpStatusCode.OK : HttpStatusCode.Created,
            context.CancellationToken);
    }

    [Function("PromoteContentRelease")]
    public async Task<HttpResponseData> Promote(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "ops/content/releases/{manifestId}/promote")] HttpRequestData request,
        string manifestId,
        FunctionContext context)
    {
        context.GetUserInRole(OperatorRole);
        var result = await releases.PromoteAsync(manifestId, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("RollbackContentRelease")]
    public async Task<HttpResponseData> Rollback(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "ops/content/releases/{manifestId}/rollback")] HttpRequestData request,
        string manifestId,
        FunctionContext context)
    {
        context.GetUserInRole(OperatorRole);
        var result = await releases.RollbackAsync(manifestId, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("GetActiveContentManifest")]
    public async Task<HttpResponseData> GetActiveManifest(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "content/releases/active/public")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var manifest = await releases.GetActiveManifestAsync(context.CancellationToken);
        return manifest is null
            ? await request.NotFound("No content release is active.", context.CancellationToken)
            : await request.JsonAsync(manifest, cancellationToken: context.CancellationToken);
    }

    [Function("GetActiveContentReleaseFile")]
    public async Task<HttpResponseData> GetActiveFile(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "content/releases/active/public/files/{*path}")] HttpRequestData request,
        string path,
        FunctionContext context)
    {
        context.GetUser();
        var file = await releases.GetActivePublicFileAsync(path, context.CancellationToken);
        if (file is null)
        {
            return await request.NotFound("Content file not found.", context.CancellationToken);
        }

        var response = request.CreateResponse(HttpStatusCode.OK);
        response.Headers.Add(
            "Content-Type",
            path.EndsWith(".json", StringComparison.OrdinalIgnoreCase)
                ? "application/json; charset=utf-8"
                : "application/octet-stream");
        response.Headers.Add("X-Content-Type-Options", "nosniff");
        await response.Body.WriteAsync(file.Content, context.CancellationToken);
        return response;
    }
}
