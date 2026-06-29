using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

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
