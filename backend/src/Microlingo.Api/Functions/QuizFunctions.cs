using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class QuizFunctions(IQuizService quizzes)
{
    [Function("SubmitQuiz")]
    public async Task<HttpResponseData> SubmitQuiz(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "quiz/{lessonId}/submit")] HttpRequestData request,
        string lessonId,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<SubmitQuizRequest>(context.CancellationToken);
        var result = await quizzes.SubmitAsync(lessonId, body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
