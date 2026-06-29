using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
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
}
