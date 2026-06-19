using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class LeaderboardFunctions(ILeaderboardService leaderboard)
{
    [Function("GetMyLeague")]
    public async Task<HttpResponseData> GetMyLeague(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me/league")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var league = await leaderboard.GetMyLeagueAsync(context.CancellationToken);
        return await request.JsonAsync(league, cancellationToken: context.CancellationToken);
    }
}
