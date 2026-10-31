using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class TutorFunctions(ITutorService tutor)
{
    // "Explain my answer" — the premium AI tutor. Grounds the explanation in the
    // official lesson, personalises it from the caller's learning history, and
    // learns from the interaction. Authoring the caller is required so the agent
    // attributes the learner model to the right person.
    [Function("ExplainAnswer")]
    public async Task<HttpResponseData> ExplainAnswer(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "tutor/explain")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<TutorExplainRequest>(context.CancellationToken);
        var result = await tutor.ExplainAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("ChatWithTutor")]
    public async Task<HttpResponseData> ChatWithTutor(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "tutor/chat")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<TutorChatRequest>(context.CancellationToken);
        var result = await tutor.ChatAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
