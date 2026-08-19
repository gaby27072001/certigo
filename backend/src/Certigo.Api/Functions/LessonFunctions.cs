using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class LessonFunctions(IContentService content)
{
    [Function("GetLesson")]
    public async Task<HttpResponseData> GetLesson(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "tracks/{trackId}/lessons/{lessonId}")] HttpRequestData request,
        string trackId,
        string lessonId,
        FunctionContext context)
    {
        context.GetUser();
        var result = await content.GetLessonWithSnapshotAsync(
            trackId,
            lessonId,
            context.CancellationToken);
        if (result is null)
        {
            return await request.NotFound("Lesson not found.", context.CancellationToken);
        }

        var response = await request.JsonAsync(
            result.Lesson,
            cancellationToken: context.CancellationToken);
        if (result.PublicManifestId is not null)
        {
            response.Headers.Add("X-Content-Manifest-Id", result.PublicManifestId);
            response.Headers.Add("ETag", $"\"{result.PublicManifestId}\"");
        }

        return response;
    }
}
