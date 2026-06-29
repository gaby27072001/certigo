using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ShopFunctionsTests
{
    [Fact]
    public async Task GetShop_ReturnsCatalog_WhenAuthenticated()
    {
        var service = new FakeShopService();
        var function = new ShopFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/shop");

        var response = await function.GetShop(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.CatalogCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetShop_Throws_WhenUnauthenticated()
    {
        var service = new FakeShopService();
        var function = new ShopFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/shop");

        var act = () => function.GetShop(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.CatalogCallCount.Should().Be(0);
    }

    [Fact]
    public async Task PurchaseShopItem_Returns200_AndForwardsBody_WhenAuthenticated()
    {
        var service = new FakeShopService();
        var function = new ShopFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new PurchaseRequest("item-1", "client-purchase-1");
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/shop/purchase", body);

        var response = await function.PurchaseShopItem(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.PurchaseCallCount.Should().Be(1);
        service.LastPurchase!.ItemId.Should().Be("item-1");
    }

    [Fact]
    public async Task PurchaseShopItem_Throws_WhenUnauthenticated()
    {
        var service = new FakeShopService();
        var function = new ShopFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/shop/purchase");

        var act = () => function.PurchaseShopItem(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.PurchaseCallCount.Should().Be(0);
    }

    [Fact]
    public async Task PurchaseShopItem_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeShopService();
        var function = new ShopFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/shop/purchase");

        var act = () => function.PurchaseShopItem(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.PurchaseCallCount.Should().Be(0);
    }
}
