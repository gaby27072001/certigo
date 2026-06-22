using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class AchievementFunctions(IAchievementService achievements)
{
    [Function("GetAchievements")]
    public async Task<HttpResponseData> GetAchievements(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "achievements")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var board = await achievements.GetAllAsync(context.CancellationToken);
        return await request.JsonAsync(board, cancellationToken: context.CancellationToken);
    }
}
