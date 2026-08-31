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
    IPublicContentFileService publicFiles,
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
        var etag = QuoteETag(result.ETag);
        if (request.Headers.TryGetValues("If-None-Match", out var values)
            && values.Any(value => string.Equals(value, etag, StringComparison.Ordinal)))
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

    [Function("GetPublicContentReleaseFile")]
    public async Task<HttpResponseData> GetPublicFile(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route =
                "content/releases/{releaseId}/manifests/{publicManifestId}/files/{hash}/{*path}")]
        HttpRequestData request,
        string releaseId,
        string publicManifestId,
        string hash,
        string path,
        FunctionContext context)
    {
        context.GetUser();
        var file = await publicFiles.GetAsync(
            releaseId,
            publicManifestId,
            hash,
            path,
            context.CancellationToken);
        var etag = QuoteETag($"sha256:{file.Hash}");

        if (MatchesIfNoneMatch(request, etag))
        {
            var notModified = request.CreateResponse(HttpStatusCode.NotModified);
            AddPublicFileHeaders(notModified, file, etag, includeLength: false);
            return notModified;
        }

        if (request.Headers.TryGetValues("Range", out _))
        {
            var rangeNotSatisfiable = request.CreateResponse(HttpStatusCode.RequestedRangeNotSatisfiable);
            AddPublicFileHeaders(rangeNotSatisfiable, file, etag, includeLength: false);
            rangeNotSatisfiable.Headers.Add("Content-Range", $"bytes */{file.Content.Length}");
            return rangeNotSatisfiable;
        }

        var response = request.CreateResponse(HttpStatusCode.OK);
        AddPublicFileHeaders(response, file, etag, includeLength: true);
        await response.Body.WriteAsync(file.Content, context.CancellationToken);
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

    private static string QuoteETag(string value)
        => value.StartsWith('"') ? value : $"\"{value}\"";

    private static bool MatchesIfNoneMatch(HttpRequestData request, string etag)
        => request.Headers.TryGetValues("If-None-Match", out var values)
           && values
               .SelectMany(value => value.Split(','))
               .Select(value => value.Trim())
               .Any(value => value == "*"
                             || string.Equals(value, etag, StringComparison.Ordinal)
                             || string.Equals(value, $"W/{etag}", StringComparison.Ordinal));

    private static void AddPublicFileHeaders(
        HttpResponseData response,
        PublicContentFileResult file,
        string etag,
        bool includeLength)
    {
        response.Headers.Add("ETag", etag);
        response.Headers.Add("Cache-Control", "private, max-age=31536000, immutable");
        response.Headers.Add("Accept-Ranges", "none");
        response.Headers.Add("Content-Type", file.ContentType);
        response.Headers.Add("X-Content-SHA256", file.Hash);
        response.Headers.Add("X-Content-Release-Id", file.ReleaseId);
        response.Headers.Add("X-Content-Manifest-Id", file.PublicManifestId);
        if (includeLength)
        {
            response.Headers.Add("Content-Length", file.Content.Length.ToString());
        }
    }
}
