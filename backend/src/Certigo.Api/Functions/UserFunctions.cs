using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class UserFunctions(IUserService users)
{
    [Function("GetMe")]
    public async Task<HttpResponseData> GetMe(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var profile = await users.GetOrProvisionAsync(context.CancellationToken);
        return await request.JsonAsync(profile, cancellationToken: context.CancellationToken);
    }

    [Function("SetActiveTrack")]
    public async Task<HttpResponseData> SetActiveTrack(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "me/active-track")]
        HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<SetActiveTrackRequest>(context.CancellationToken);
        if (string.IsNullOrWhiteSpace(body.TrackId))
        {
            throw new BadRequestException("A certification track id is required.");
        }

        var profile = await users.SetActiveTrackAsync(
            body.TrackId,
            body.ExpectedTrackId,
            context.CancellationToken);
        return await request.JsonAsync(profile, cancellationToken: context.CancellationToken);
    }
}
