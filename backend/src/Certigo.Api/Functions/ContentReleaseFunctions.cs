using System.Net;
using Certigo.Api.Auth;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class ContentReleaseFunctions(
    IContentReleaseService releases,
    ContentAdminAuthorization adminAuthorization)
{
    [Function("ImportContentRelease")]
    public async Task<HttpResponseData> Import(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "admin/content/releases/{releaseId}/import")]
        HttpRequestData request,
        string releaseId,
        FunctionContext context)
    {
        var actorId = adminAuthorization.Require(context);
        var result = await releases.ImportAsync(releaseId, actorId, context.CancellationToken);
        return await request.JsonAsync(
            result,
            result.AlreadyImported ? HttpStatusCode.OK : HttpStatusCode.Created,
            context.CancellationToken);
    }

    [Function("GetContentReleasePointer")]
    public async Task<HttpResponseData> GetPointer(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "admin/content/releases/pointer")]
        HttpRequestData request,
        FunctionContext context)
    {
        _ = adminAuthorization.Require(context);
        var pointer = await releases.GetPointerAsync(context.CancellationToken)
            ?? throw new ContentUnavailableException("No active content release exists.");
        var response = await request.JsonAsync(pointer, cancellationToken: context.CancellationToken);
        response.Headers.Add("ETag", pointer.ETag);
        return response;
    }

    [Function("PromoteContentRelease")]
    public async Task<HttpResponseData> Promote(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "admin/content/releases/{releaseId}/promote")]
        HttpRequestData request,
        string releaseId,
        FunctionContext context)
    {
        var actorId = adminAuthorization.Require(context);
        var pointer = await releases.PromoteAsync(
            releaseId,
            RequireIfMatch(request),
            actorId,
            context.CancellationToken);
        var response = await request.JsonAsync(pointer, cancellationToken: context.CancellationToken);
        response.Headers.Add("ETag", pointer.ETag);
        return response;
    }

    [Function("RollbackContentRelease")]
    public async Task<HttpResponseData> Rollback(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "admin/content/releases/rollback")]
        HttpRequestData request,
        FunctionContext context)
    {
        var actorId = adminAuthorization.Require(context);
        var pointer = await releases.RollbackAsync(
            RequireIfMatch(request),
            actorId,
            context.CancellationToken);
        var response = await request.JsonAsync(pointer, cancellationToken: context.CancellationToken);
        response.Headers.Add("ETag", pointer.ETag);
        return response;
    }

    [Function("GetActivePublicContentManifest")]
    public async Task<HttpResponseData> GetActivePublicManifest(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "content/releases/active/manifest")]
        HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var result = await releases.GetActivePublicManifestAsync(context.CancellationToken)
            ?? throw new ContentUnavailableException("No active public content manifest exists.");
        var etag = ContentHttpCaching.QuoteETag(result.ETag);
        if (ContentHttpCaching.MatchesIfNoneMatch(request, etag))
        {
            var notModified = request.CreateResponse(HttpStatusCode.NotModified);
            notModified.Headers.Add("ETag", etag);
            notModified.Headers.Add("X-Content-Release-Id", result.ReleaseId);
            notModified.Headers.Add("X-Content-Manifest-Id", result.Manifest.ManifestId);
            notModified.Headers.Add("Cache-Control", "private, no-cache");
            notModified.Headers.Add(
                "Access-Control-Expose-Headers",
                "ETag, X-Content-Release-Id, X-Content-Manifest-Id");
            return notModified;
        }

        var response = await request.JsonAsync(
            result.Manifest with { ReleaseId = result.ReleaseId },
            cancellationToken: context.CancellationToken);
        response.Headers.Add("ETag", etag);
        response.Headers.Add("X-Content-Release-Id", result.ReleaseId);
        response.Headers.Add("X-Content-Manifest-Id", result.Manifest.ManifestId);
        response.Headers.Add("Cache-Control", "private, no-cache");
        response.Headers.Add(
            "Access-Control-Expose-Headers",
            "ETag, X-Content-Release-Id, X-Content-Manifest-Id");
        return response;
    }

    private static string RequireIfMatch(HttpRequestData request)
    {
        var value = request.Headers.TryGetValues("If-Match", out var values)
            ? values.FirstOrDefault()
            : null;
        return string.IsNullOrWhiteSpace(value)
            ? throw new ContentReleasePreconditionRequiredException(
                "If-Match is required for content pointer mutation.")
            : value.Trim();
    }

}
