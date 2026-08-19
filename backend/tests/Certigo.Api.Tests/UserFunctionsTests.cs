using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class UserFunctionsTests
{
    [Fact]
    public async Task GetMe_ReturnsProfile_WhenAuthenticated()
    {
        var service = new FakeUserService();
        var function = new UserFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me");

        var response = await function.GetMe(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.CallCount.Should().Be(1);
        var payload = await response.ReadJsonAsync<UserProfileDto>();
        payload.DisplayName.Should().Be("Test User");
    }

    [Fact]
    public async Task GetMe_Throws_WhenUnauthenticated()
    {
        var service = new FakeUserService();
        var function = new UserFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me");

        var act = () => function.GetMe(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task SetActiveTrack_UpdatesAuthenticatedProfile()
    {
        var service = new FakeUserService();
        var function = new UserFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new SetActiveTrackRequest("dp-900", "az-900");
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/me/active-track",
            body);

        var response = await function.SetActiveTrack(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.SetActiveTrackCallCount.Should().Be(1);
        service.LastTrackId.Should().Be("dp-900");
        service.LastExpectedTrackId.Should().Be("az-900");
        var payload = await response.ReadJsonAsync<UserProfileDto>();
        payload.ActiveTrackId.Should().Be("dp-900");
    }

    [Fact]
    public async Task SetActiveTrack_Throws_WhenUnauthenticated()
    {
        var service = new FakeUserService();
        var function = new UserFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/me/active-track",
            new SetActiveTrackRequest("dp-900", null));

        var act = () => function.SetActiveTrack(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.SetActiveTrackCallCount.Should().Be(0);
    }

    [Fact]
    public async Task SetActiveTrack_RejectsBlankTrackId()
    {
        var service = new FakeUserService();
        var function = new UserFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "POST",
            "https://localhost/api/me/active-track",
            new SetActiveTrackRequest(" ", null));

        var act = () => function.SetActiveTrack(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.SetActiveTrackCallCount.Should().Be(0);
    }
}
