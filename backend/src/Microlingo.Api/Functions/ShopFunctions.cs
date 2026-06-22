using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microlingo.Api.Http;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;

namespace Microlingo.Api.Functions;

public sealed class ShopFunctions(IShopService shop)
{
    [Function("GetShop")]
    public async Task<HttpResponseData> GetShop(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "shop")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var catalog = await shop.GetCatalogAsync(context.CancellationToken);
        return await request.JsonAsync(catalog, cancellationToken: context.CancellationToken);
    }

    [Function("PurchaseShopItem")]
    public async Task<HttpResponseData> PurchaseShopItem(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "shop/purchase")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<PurchaseRequest>(context.CancellationToken);
        var result = await shop.PurchaseAsync(body, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }
}
