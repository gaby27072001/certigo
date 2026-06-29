using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class QuestFunctionsTests
{
    [Fact]
    public async Task GetQuests_ReturnsBoard_WhenAuthenticated()
    {
        var service = new FakeQuestService();
        var function = new QuestFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/quests");

        var response = await function.GetQuests(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.BoardCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetQuests_Throws_WhenUnauthenticated()
    {
        var service = new FakeQuestService();
        var function = new QuestFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/quests");

        var act = () => function.GetQuests(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.BoardCallCount.Should().Be(0);
    }

    [Fact]
    public async Task ClaimQuest_Returns200_AndForwardsBody_WhenAuthenticated()
    {
        var service = new FakeQuestService();
        var function = new QuestFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new ClaimQuestRequest("quest-1");
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/quests/claim", body);

        var response = await function.ClaimQuest(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.ClaimCallCount.Should().Be(1);
        service.LastClaim!.QuestId.Should().Be("quest-1");
    }

    [Fact]
    public async Task ClaimQuest_Throws_WhenUnauthenticated()
    {
        var service = new FakeQuestService();
        var function = new QuestFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/quests/claim");

        var act = () => function.ClaimQuest(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.ClaimCallCount.Should().Be(0);
    }

    [Fact]
    public async Task ClaimQuest_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeQuestService();
        var function = new QuestFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/quests/claim");

        var act = () => function.ClaimQuest(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.ClaimCallCount.Should().Be(0);
    }
}
