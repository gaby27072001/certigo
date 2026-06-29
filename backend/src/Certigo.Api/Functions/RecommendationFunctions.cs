using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

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
