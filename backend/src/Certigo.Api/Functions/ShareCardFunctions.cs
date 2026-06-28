using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

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
