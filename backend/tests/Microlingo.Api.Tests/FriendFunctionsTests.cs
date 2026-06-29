using System.Collections.Generic;
using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class FriendFunctionsTests
{
    [Fact]
    public async Task GetFriends_ReturnsList_WhenAuthenticated()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/friends");

        var response = await function.GetFriends(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.ListCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetFriends_Throws_WhenUnauthenticated()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/friends");

        var act = () => function.GetFriends(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.ListCallCount.Should().Be(0);
    }

    [Fact]
    public async Task AddFriend_Returns200_AndForwardsBody_WhenSuccessful()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new AddFriendRequest("somehandle");
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/friends", body);

        var response = await function.AddFriend(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.AddCallCount.Should().Be(1);
        service.LastAddedHandle.Should().Be("somehandle");
    }

    [Fact]
    public async Task AddFriend_Returns400_WhenFailed()
    {
        var service = new FakeFriendService
        {
            AddResult = new FriendActionResultDto(false, null, "User not found", new FriendListDto(0, new List<FriendDto>())),
        };
        var function = new FriendFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var body = new AddFriendRequest("ghost");
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/friends", body);

        var response = await function.AddFriend(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        service.AddCallCount.Should().Be(1);
    }

    [Fact]
    public async Task AddFriend_Throws_WhenUnauthenticated()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/friends");

        var act = () => function.AddFriend(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.AddCallCount.Should().Be(0);
    }

    [Fact]
    public async Task AddFriend_ThrowsBadRequest_WhenBodyMissing()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "POST", "https://localhost/api/friends");

        var act = () => function.AddFriend(request, context);

        await Assert.ThrowsAsync<BadRequestException>(act);
        service.AddCallCount.Should().Be(0);
    }

    [Fact]
    public async Task RemoveFriend_Returns200_AndForwardsId_WhenAuthenticated()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "DELETE", "https://localhost/api/friends/friend-1");

        var response = await function.RemoveFriend(request, context, "friend-1");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.RemoveCallCount.Should().Be(1);
        service.LastRemovedUserId.Should().Be("friend-1");
    }

    [Fact]
    public async Task RemoveFriend_Throws_WhenUnauthenticated()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "DELETE", "https://localhost/api/friends/friend-1");

        var act = () => function.RemoveFriend(request, context, "friend-1");

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.RemoveCallCount.Should().Be(0);
    }

    [Fact]
    public async Task GetFriendLeaderboard_ReturnsBoard_WhenAuthenticated()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/friends/leaderboard");

        var response = await function.GetFriendLeaderboard(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.LeaderboardCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetFriendLeaderboard_Throws_WhenUnauthenticated()
    {
        var service = new FakeFriendService();
        var function = new FriendFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/friends/leaderboard");

        var act = () => function.GetFriendLeaderboard(request, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.LeaderboardCallCount.Should().Be(0);
    }
}
