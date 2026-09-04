using System.Net;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class OfflineContentFunctions(IOfflineContentService content)
{
    [Function("GetActiveOfflineContentManifest")]
    public async Task<HttpResponseData> GetActiveManifest(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "content/releases/active/offline-manifest")]
        HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var manifest = await content.GetActiveManifestAsync(context.CancellationToken);
        var response = await request.JsonAsync(
            manifest,
            cancellationToken: context.CancellationToken);
        AddManifestHeaders(response, manifest.ManifestId, manifest.Version);
        response.Headers.Add("Cache-Control", "private, no-cache");
        return response;
    }

    [Function("GetPinnedOfflineCatalog")]
    public async Task<HttpResponseData> GetCatalog(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "content/releases/{manifestId}/offline/catalog")]
        HttpRequestData request,
        string manifestId,
        FunctionContext context)
    {
        context.GetUser();
        var payload = await content.GetCatalogAsync(
            manifestId,
            context.CancellationToken);
        EnsureExpectedHash(request, payload);
        return await PayloadResponseAsync(request, payload, context.CancellationToken);
    }

    [Function("GetPinnedOfflineLesson")]
    public async Task<HttpResponseData> GetLesson(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "content/releases/{manifestId}/offline/tracks/{trackId}/lessons/{lessonId}")]
        HttpRequestData request,
        string manifestId,
        string trackId,
        string lessonId,
        FunctionContext context)
    {
        context.GetUser();
        var payload = await content.GetLessonAsync(
            manifestId,
            trackId,
            lessonId,
            context.CancellationToken);
        if (payload is not null)
        {
            EnsureExpectedHash(request, payload);
        }
        return payload is null
            ? await request.NotFound("Lesson not found.", context.CancellationToken)
            : await PayloadResponseAsync(request, payload, context.CancellationToken);
    }

    private static async Task<HttpResponseData> PayloadResponseAsync(
        HttpRequestData request,
        OfflineContentPayload payload,
        CancellationToken cancellationToken)
    {
        var response = await request.JsonBytesAsync(
            payload.Content,
            cancellationToken: cancellationToken);
        AddManifestHeaders(response, payload.PublicManifestId, $"sha256:{payload.Sha256}");
        response.Headers.Add("X-Content-SHA256", payload.Sha256);
        response.Headers.Add("Content-Length", payload.Content.Length.ToString(
            System.Globalization.CultureInfo.InvariantCulture));
        response.Headers.Add("Cache-Control", "private, max-age=31536000, immutable");
        return response;
    }

    private static void EnsureExpectedHash(
        HttpRequestData request,
        OfflineContentPayload payload)
    {
        var expected = request.Query["sha256"];
        if (string.IsNullOrWhiteSpace(expected))
        {
            throw new BadRequestException("The sha256 query parameter is required.");
        }

        if (!string.Equals(expected, payload.Sha256, StringComparison.Ordinal))
        {
            throw new ContentReleaseStateException(
                "The requested offline payload hash does not match the pinned release.");
        }
    }

    private static void AddManifestHeaders(
        HttpResponseData response,
        string publicManifestId,
        string etag)
    {
        response.Headers.Add("X-Content-Manifest-Id", publicManifestId);
        response.Headers.Add("ETag", $"\"{etag}\"");
        response.Headers.Add(
            "Access-Control-Expose-Headers",
            "ETag, X-Content-Manifest-Id, X-Content-SHA256, Content-Length");
    }
}
