using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

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

    [Function("GetMyLeagueResolution")]
    public async Task<HttpResponseData> GetMyLeagueResolution(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me/league/resolution")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var resolution = await leaderboard.PreviewResolutionAsync(context.CancellationToken);
        return await request.JsonAsync(resolution, cancellationToken: context.CancellationToken);
    }
}
