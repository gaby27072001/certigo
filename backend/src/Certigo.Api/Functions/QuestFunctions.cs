using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

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
