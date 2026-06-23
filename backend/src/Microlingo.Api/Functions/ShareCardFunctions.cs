using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class ShareCardFunctions(IShareCardService shareCards)
{
    [Function("GetDailyShareCard")]
    public async Task<HttpResponseData> GetDailyShareCard(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "share/daily")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var card = await shareCards.GetDailyAsync(context.CancellationToken);
        return await request.JsonAsync(card, cancellationToken: context.CancellationToken);
    }
}
