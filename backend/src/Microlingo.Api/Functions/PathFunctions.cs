using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

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
