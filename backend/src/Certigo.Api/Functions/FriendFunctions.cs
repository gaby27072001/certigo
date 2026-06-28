using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;

namespace Certigo.Api.Functions;

public sealed class FriendFunctions(IFriendService friends)
{
    [Function("GetFriends")]
    public async Task<HttpResponseData> GetFriends(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "friends")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var list = await friends.ListAsync(context.CancellationToken);
        return await request.JsonAsync(list, cancellationToken: context.CancellationToken);
    }

    [Function("AddFriend")]
    public async Task<HttpResponseData> AddFriend(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "friends")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var body = await request.ReadJsonAsync<AddFriendRequest>(context.CancellationToken);
        var result = await friends.AddByHandleAsync(body.Handle, context.CancellationToken);
        var status = result.Success ? HttpStatusCode.OK : HttpStatusCode.BadRequest;
        return await request.JsonAsync(result, status, context.CancellationToken);
    }

    [Function("RemoveFriend")]
    public async Task<HttpResponseData> RemoveFriend(
        [HttpTrigger(AuthorizationLevel.Anonymous, "delete", Route = "friends/{friendId}")] HttpRequestData request,
        FunctionContext context,
        string friendId)
    {
        context.GetUser();
        var result = await friends.RemoveAsync(friendId, context.CancellationToken);
        return await request.JsonAsync(result, cancellationToken: context.CancellationToken);
    }

    [Function("GetFriendLeaderboard")]
    public async Task<HttpResponseData> GetFriendLeaderboard(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "friends/leaderboard")] HttpRequestData request,
        FunctionContext context)
    {
        context.GetUser();
        var board = await friends.LeaderboardAsync(context.CancellationToken);
        return await request.JsonAsync(board, cancellationToken: context.CancellationToken);
    }
}
