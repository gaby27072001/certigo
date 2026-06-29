using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class ExamFunctions(IExamService exams)
{
    [Function("GenerateMockExam")]
    public async Task<HttpResponseData> GenerateMockExam(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "exam/generate")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<MockExamRequest>(context.CancellationToken);
        var result = await exams.GenerateAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("SubmitMockExam")]
    public async Task<HttpResponseData> SubmitMockExam(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "exam/submit")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<SubmitMockExamRequest>(context.CancellationToken);
        var result = await exams.SubmitAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
