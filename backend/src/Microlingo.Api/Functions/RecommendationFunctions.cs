using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class RecommendationFunctions(IRecommendationService recommendations)
{
    [Function("GetNextBest")]
    public async Task<HttpResponseData> GetNextBest(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "me/recommendations/{trackId}")] HttpRequestData request,
        string trackId,
        FunctionContext context)
    {
        context.GetUser();
        var nextBest = await recommendations.GetNextBestAsync(trackId, context.CancellationToken);
        return await request.JsonAsync(nextBest, cancellationToken: context.CancellationToken);
    }
}
