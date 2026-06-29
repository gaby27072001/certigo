using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ShareCardFunctionsTests
{
    [Fact]
    public async Task GetDailyShareCard_ReturnsCard_WhenAuthenticated()
    {
        var service = new FakeShareCardService();
        var function = new ShareCardFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/share/daily");

        var response = await function.GetDailyShareCard(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.CallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetDailyShareCard_Throws_WhenUnauthenticated()
    {
        var service = new FakeShareCardService();
        var function = new ShareCardFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/share/daily");

        var act = () => function.GetDailyShareCard(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.CallCount.Should().Be(0);
    }
}
