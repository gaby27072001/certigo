using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

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
}
