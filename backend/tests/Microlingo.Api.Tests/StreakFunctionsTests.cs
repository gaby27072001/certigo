using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class StreakFunctionsTests
{
    [Fact]
    public async Task GetStreakStatus_ReturnsStatus_WhenAuthenticated()
    {
        var service = new FakeStreakRepairService();
        var function = new StreakFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/streak");

        var response = await function.GetStreakStatus(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.StatusCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetStreakStatus_Throws_WhenUnauthenticated()
    {
        var service = new FakeStreakRepairService();
        var function = new StreakFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/streak");

        var act = () => function.GetStreakStatus(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.StatusCallCount.Should().Be(0);
    }

    [Fact]
    public async Task RepairStreak_Returns200_WhenSuccessful()
    {
        var service = new FakeStreakRepairService();
        var function = new StreakFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new StreakRepairRequest("client-repair-1");
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/streak/repair", body);

        var response = await function.RepairStreak(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.RepairCallCount.Should().Be(1);
        service.LastRepair!.ClientRepairId.Should().Be("client-repair-1");
    }

    [Fact]
    public async Task RepairStreak_Returns400_WhenFailed()
    {
        var service = new FakeStreakRepairService
        {
            RepairResult = new StreakRepairResultDto(false, 5, 10, 30, new DateOnly(2025, 1, 5), "Already repaired"),
        };
        var function = new StreakFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new StreakRepairRequest("client-repair-1");
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/streak/repair", body);

        var response = await function.RepairStreak(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        service.RepairCallCount.Should().Be(1);
    }

    [Fact]
    public async Task RepairStreak_Throws_WhenUnauthenticated()
    {
        var service = new FakeStreakRepairService();
        var function = new StreakFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/streak/repair");

        var act = () => function.RepairStreak(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.RepairCallCount.Should().Be(0);
    }

    [Fact]
    public async Task RepairStreak_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeStreakRepairService();
        var function = new StreakFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/streak/repair");

        var act = () => function.RepairStreak(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.RepairCallCount.Should().Be(0);
    }
}
