using System.Net;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace Certigo.Api.Functions;

public sealed class PortableAchievementFunctions(IPortableAchievementService portableAchievements)
{
    [Function("IssuePortableAchievement")]
    public async Task<HttpResponseData> Issue(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "me/portable-achievements")]
        HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var command = await request.ReadJsonAsync<IssuePortableAchievementRequest>(
            context.CancellationToken);
        var result = await portableAchievements.IssueAsync(command, context.CancellationToken);
        return await request.JsonAsync(
            result,
            result.IdempotentReplay ? HttpStatusCode.OK : HttpStatusCode.Created,
            context.CancellationToken);
    }

    [Function("GetPortableAchievement")]
    public async Task<HttpResponseData> Get(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "get",
            Route = "me/portable-achievements/{proofId}")]
        HttpRequestData request,
        string proofId,
        FunctionContext context)
    {
        context.GetUser();
        var result = await portableAchievements.GetAsync(proofId, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("VerifyPortableAchievement")]
    public async Task<HttpResponseData> Verify(
        [HttpTrigger(
            AuthorizationLevel.Anonymous,
            "post",
            Route = "portable-achievements/verify")]
        HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var command = await request.ReadJsonAsync<VerifyPortableAchievementRequest>(
            context.CancellationToken);
        var result = await portableAchievements.VerifyAsync(command, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
