using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class NotificationFunctionsTests
{
    [Fact]
    public async Task GetNotificationPlan_ReturnsPlan_WhenAuthenticated()
    {
        var service = new FakeNotificationService();
        var function = new NotificationFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/notifications/plan");

        var response = await function.GetNotificationPlan(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.PlanCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetNotificationPlan_Throws_WhenUnauthenticated()
    {
        var service = new FakeNotificationService();
        var function = new NotificationFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/notifications/plan");

        var act = () => function.GetNotificationPlan(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.PlanCallCount.Should().Be(0);
    }

    [Fact]
    public async Task GetNotificationSettings_ReturnsSettings_WhenAuthenticated()
    {
        var service = new FakeNotificationService();
        var function = new NotificationFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/notifications/settings");

        var response = await function.GetNotificationSettings(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.SettingsCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetNotificationSettings_Throws_WhenUnauthenticated()
    {
        var service = new FakeNotificationService();
        var function = new NotificationFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/me/notifications/settings");

        var act = () => function.GetNotificationSettings(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.SettingsCallCount.Should().Be(0);
    }

    [Fact]
    public async Task UpdateNotificationSettings_Returns200_AndForwardsBody_WhenAuthenticated()
    {
        var service = new FakeNotificationService();
        var function = new NotificationFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new UpdateNotificationSettingsRequest(true, 0, 22, 7, 19, 3, true, true, true);
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/me/notifications/settings", body);

        var response = await function.UpdateNotificationSettings(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.UpdateCallCount.Should().Be(1);
        service.LastUpdate!.Enabled.Should().BeTrue();
    }

    [Fact]
    public async Task UpdateNotificationSettings_Throws_WhenUnauthenticated()
    {
        var service = new FakeNotificationService();
        var function = new NotificationFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/me/notifications/settings");

        var act = () => function.UpdateNotificationSettings(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.UpdateCallCount.Should().Be(0);
    }

    [Fact]
    public async Task UpdateNotificationSettings_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeNotificationService();
        var function = new NotificationFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/me/notifications/settings");

        var act = () => function.UpdateNotificationSettings(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.UpdateCallCount.Should().Be(0);
    }
}
