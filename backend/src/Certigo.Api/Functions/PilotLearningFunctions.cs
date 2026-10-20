using System.Net;
using Certigo.Api.Http;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class PilotLearningFunctions(IPilotLearningService pilots)
{
    [Function("GetEditorialPilotContent")]
    public async Task<HttpResponseData> GetContent(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "pilots/{pilotId}/content")] HttpRequestData request,
        string pilotId,
        FunctionContext context)
    {
        context.GetUser();
        var package = await pilots.GetContentAsync(pilotId, context.CancellationToken);
        if (package is null)
        {
            return await request.NotFound("Editorial pilot not found.", context.CancellationToken);
        }

        var response = request.CreateResponse(HttpStatusCode.OK);
        response.Headers.Add("Content-Type", "application/json; charset=utf-8");
        response.Headers.Add("Cache-Control", "no-store");
        response.Headers.Add("ETag", $"\"{package.ContentDigest}\"");
        response.Headers.Add("X-Certigo-Pilot-Content-Digest", package.ContentDigest);
        await response.Body.WriteAsync(package.Json, context.CancellationToken);
        return response;
    }

    [Function("GetEditorialPilotHistory")]
    public async Task<HttpResponseData> GetHistory(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "me/pilots/{pilotId}/history/{contentDigest}")] HttpRequestData request,
        string pilotId,
        string contentDigest,
        FunctionContext context)
    {
        context.GetUser();
        var result = await pilots.GetHistoryAsync(
            pilotId,
            contentDigest,
            context.CancellationToken);
        return result is null
            ? await request.NotFound("Editorial pilot version not found.", context.CancellationToken)
            : await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("RecordEditorialPilotLessonAccess")]
    public Task<HttpResponseData> RecordAccess(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "me/pilots/{pilotId}/lessons/{lessonId}/access/{contentDigest}")]
        HttpRequestData request,
        string pilotId,
        string lessonId,
        string contentDigest,
        FunctionContext context) =>
        RecordActivityAsync(request, pilotId, lessonId, contentDigest, false, context);

    [Function("MarkEditorialPilotLessonRead")]
    public Task<HttpResponseData> MarkRead(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "me/pilots/{pilotId}/lessons/{lessonId}/read/{contentDigest}")]
        HttpRequestData request,
        string pilotId,
        string lessonId,
        string contentDigest,
        FunctionContext context) =>
        RecordActivityAsync(request, pilotId, lessonId, contentDigest, true, context);

    private async Task<HttpResponseData> RecordActivityAsync(
        HttpRequestData request,
        string pilotId,
        string lessonId,
        string contentDigest,
        bool markRead,
        FunctionContext context)
    {
        context.GetUser();
        var result = await pilots.RecordAccessAsync(
            pilotId,
            lessonId,
            contentDigest,
            markRead,
            context.CancellationToken);
        return result is null
            ? await request.NotFound(
                "Editorial pilot lesson or version not found.",
                context.CancellationToken)
            : await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
