using System.Globalization;
using System.Net;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class PublicContentFunctions(IPublicContentFileService publicFiles)
{
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
        var etag = ContentHttpCaching.QuoteETag($"sha256:{file.Hash}");

        if (ContentHttpCaching.MatchesIfNoneMatch(request, etag))
        {
            var notModified = request.CreateResponse(HttpStatusCode.NotModified);
            AddPublicFileHeaders(notModified, file, etag, includeLength: false);
            return notModified;
        }

        if (request.Headers.TryGetValues("Range", out _))
        {
            var rangeNotSatisfiable =
                request.CreateResponse(HttpStatusCode.RequestedRangeNotSatisfiable);
            AddPublicFileHeaders(
                rangeNotSatisfiable,
                file,
                etag,
                includeLength: false,
                cacheControl: "no-store");
            rangeNotSatisfiable.Headers.Add(
                "Content-Range",
                $"bytes */{file.Content.Length.ToString(CultureInfo.InvariantCulture)}");
            return rangeNotSatisfiable;
        }

        var response = request.CreateResponse(HttpStatusCode.OK);
        AddPublicFileHeaders(response, file, etag, includeLength: true);
        await response.Body.WriteAsync(file.Content, context.CancellationToken);
        return response;
    }

    private static void AddPublicFileHeaders(
        HttpResponseData response,
        PublicContentFileResult file,
        string etag,
        bool includeLength,
        string cacheControl = "private, max-age=31536000, immutable")
    {
        response.Headers.Add("ETag", etag);
        response.Headers.Add("Cache-Control", cacheControl);
        response.Headers.Add("Accept-Ranges", "none");
        response.Headers.Add("Content-Type", file.ContentType);
        response.Headers.Add("X-Content-SHA256", file.Hash);
        response.Headers.Add("X-Content-Release-Id", file.ReleaseId);
        response.Headers.Add("X-Content-Manifest-Id", file.PublicManifestId);
        if (includeLength)
        {
            response.Headers.Add(
                "Content-Length",
                file.Content.Length.ToString(CultureInfo.InvariantCulture));
        }
    }
}

internal static class ContentHttpCaching
{
    public static string QuoteETag(string value)
        => value.StartsWith('"') ? value : $"\"{value}\"";

    public static bool MatchesIfNoneMatch(HttpRequestData request, string etag)
        => request.Headers.TryGetValues("If-None-Match", out var values)
           && values
               .SelectMany(value => value.Split(','))
               .Select(value => value.Trim())
               .Any(value => value == "*"
                             || string.Equals(value, etag, StringComparison.Ordinal)
                             || string.Equals(value, $"W/{etag}", StringComparison.Ordinal));
}
