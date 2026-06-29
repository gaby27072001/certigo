using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class SeasonFunctionsTests
{
    [Fact]
    public async Task GetSeason_ReturnsSeason_WhenAuthenticated()
    {
        var service = new FakeSeasonService();
        var function = new SeasonFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/season");

        var response = await function.GetSeason(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.SeasonCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetSeason_Throws_WhenUnauthenticated()
    {
        var service = new FakeSeasonService();
        var function = new SeasonFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/season");

        var act = () => function.GetSeason(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.SeasonCallCount.Should().Be(0);
    }

    [Fact]
    public async Task ClaimSeason_Returns200_AndForwardsBody_WhenAuthenticated()
    {
        var service = new FakeSeasonService();
        var function = new SeasonFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new ClaimSeasonRequest("season-1");
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/season/claim", body);

        var response = await function.ClaimSeason(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.ClaimCallCount.Should().Be(1);
        service.LastClaim!.SeasonId.Should().Be("season-1");
    }

    [Fact]
    public async Task ClaimSeason_Throws_WhenUnauthenticated()
    {
        var service = new FakeSeasonService();
        var function = new SeasonFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/season/claim");

        var act = () => function.ClaimSeason(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.ClaimCallCount.Should().Be(0);
    }

    [Fact]
    public async Task ClaimSeason_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeSeasonService();
        var function = new SeasonFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/season/claim");

        var act = () => function.ClaimSeason(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.ClaimCallCount.Should().Be(0);
    }
}
