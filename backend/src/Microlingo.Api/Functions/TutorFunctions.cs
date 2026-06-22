using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

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
}
