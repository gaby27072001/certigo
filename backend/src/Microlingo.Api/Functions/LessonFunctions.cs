using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

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
        var lesson = await content.GetLessonAsync(trackId, lessonId, context.CancellationToken);
        return lesson is null
            ? await request.NotFound("Lesson not found.", context.CancellationToken)
            : await request.JsonAsync(lesson, cancellationToken: context.CancellationToken);
    }
}
