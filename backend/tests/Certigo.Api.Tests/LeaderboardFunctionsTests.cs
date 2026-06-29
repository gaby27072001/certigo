using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class LeaderboardFunctionsTests
{
    [Fact]
    public async Task GetMyLeague_ReturnsLeague_WhenAuthenticated()
    {
        var service = new FakeLeaderboardService();
        var function = new LeaderboardFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/league");

        var response = await function.GetMyLeague(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.LeagueCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetMyLeague_Throws_WhenUnauthenticated()
    {
        var service = new FakeLeaderboardService();
        var function = new LeaderboardFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/league");

        var act = () => function.GetMyLeague(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.LeagueCallCount.Should().Be(0);
    }

    [Fact]
    public async Task GetMyLeagueResolution_ReturnsResolution_WhenAuthenticated()
    {
        var service = new FakeLeaderboardService();
        var function = new LeaderboardFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/league/resolution");

        var response = await function.GetMyLeagueResolution(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.ResolutionCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetMyLeagueResolution_Throws_WhenUnauthenticated()
    {
        var service = new FakeLeaderboardService();
        var function = new LeaderboardFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/league/resolution");

        var act = () => function.GetMyLeagueResolution(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.ResolutionCallCount.Should().Be(0);
    }
}
