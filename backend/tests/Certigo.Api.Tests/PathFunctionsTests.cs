using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class PathFunctionsTests
{
    [Fact]
    public async Task GetMyPath_ReturnsPath_WhenAuthenticated()
    {
        var service = new FakePathService();
        var function = new PathFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/paths/track-1");

        var response = await function.GetMyPath(request, "track-1", context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.CallCount.Should().Be(1);
        service.LastTrackId.Should().Be("track-1");
        var payload = await response.ReadJsonAsync<PathDto>();
        payload.TrackId.Should().Be("track-1");
    }

    [Fact]
    public async Task GetMyPath_Throws_WhenUnauthenticated()
    {
        var service = new FakePathService();
        var function = new PathFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/paths/track-1");

        var act = () => function.GetMyPath(request, "track-1", context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.CallCount.Should().Be(0);
    }
}
