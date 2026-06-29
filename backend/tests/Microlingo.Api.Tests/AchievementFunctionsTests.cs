using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class AchievementFunctionsTests
{
    [Fact]
    public async Task GetAchievements_ReturnsBoard_WhenAuthenticated()
    {
        var service = new FakeAchievementService();
        var function = new AchievementFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/achievements");

        var response = await function.GetAchievements(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.CallCount.Should().Be(1);
        var payload = await response.ReadJsonAsync<AchievementBoardDto>();
        payload.Should().NotBeNull();
    }

    [Fact]
    public async Task GetAchievements_Throws_WhenUnauthenticated()
    {
        var service = new FakeAchievementService();
        var function = new AchievementFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/achievements");

        var act = () => function.GetAchievements(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.CallCount.Should().Be(0);
    }
}
