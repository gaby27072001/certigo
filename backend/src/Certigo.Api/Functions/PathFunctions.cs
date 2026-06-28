using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class PathFunctions(IPathService paths)
{
    [Function("GetMyPath")]
    public async Task<HttpResponseData> GetMyPath(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me/paths/{trackId}")] HttpRequestData request,
        string trackId,
        FunctionContext context)
    {
        context.GetUser();
        var path = await paths.GetPathAsync(trackId, context.CancellationToken);
        return await request.JsonAsync(path, cancellationToken: context.CancellationToken);
    }
}
