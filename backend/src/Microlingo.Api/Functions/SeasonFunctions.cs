using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class SeasonFunctions(ISeasonService seasons)
{
    [Function("GetSeason")]
    public async Task<HttpResponseData> GetSeason(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "season")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var season = await seasons.GetCurrentAsync(context.CancellationToken);
        return await request.JsonAsync(season, cancellationToken: context.CancellationToken);
    }

    [Function("ClaimSeason")]
    public async Task<HttpResponseData> ClaimSeason(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "season/claim")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<ClaimSeasonRequest>(context.CancellationToken);
        var result = await seasons.ClaimAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
