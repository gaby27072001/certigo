using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

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
