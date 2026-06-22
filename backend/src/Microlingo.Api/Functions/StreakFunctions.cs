using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class StreakFunctions(IStreakRepairService streak)
{
    [Function("GetStreakStatus")]
    public async Task<HttpResponseData> GetStreakStatus(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "streak")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var status = await streak.GetStatusAsync(context.CancellationToken);
        return await request.JsonAsync(status, cancellationToken: context.CancellationToken);
    }

    [Function("RepairStreak")]
    public async Task<HttpResponseData> RepairStreak(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "streak/repair")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<StreakRepairRequest>(context.CancellationToken);
        var result = await streak.RepairAsync(body, context.CancellationToken);
        var status = result.Success ? HttpStatusCode.OK : HttpStatusCode.BadRequest;
        return await request.JsonAsync(result, status, context.CancellationToken);
    }
}
