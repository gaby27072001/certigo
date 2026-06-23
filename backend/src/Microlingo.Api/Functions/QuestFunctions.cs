using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class QuestFunctions(IQuestService quests)
{
    [Function("GetQuests")]
    public async Task<HttpResponseData> GetQuests(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "quests")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var board = await quests.GetTodayAsync(context.CancellationToken);
        return await request.JsonAsync(board, cancellationToken: context.CancellationToken);
    }

    [Function("ClaimQuest")]
    public async Task<HttpResponseData> ClaimQuest(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "quests/claim")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<ClaimQuestRequest>(context.CancellationToken);
        var result = await quests.ClaimAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
