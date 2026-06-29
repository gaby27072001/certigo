using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

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
