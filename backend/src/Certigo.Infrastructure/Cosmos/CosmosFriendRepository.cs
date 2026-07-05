using Microsoft.Azure.Cosmos;
using System.Net;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosFriendRepository(CosmosContext context) : IFriendRepository
{
    public async Task<IReadOnlyList<FriendEdge>> ListAsync(string userId, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId")
            .WithParameter("@userId", userId);
        using var iterator = context.Friends.GetItemQueryIterator<FriendEdge>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(userId)
        });

        var edges = new List<FriendEdge>();
        while (iterator.HasMoreResults)
        {
            foreach (var edge in await iterator.ReadNextAsync(cancellationToken))
            {
                edges.Add(edge);
            }
        }

        return edges;
    }

    public Task<FriendEdge?> GetAsync(string userId, string friendUserId, CancellationToken cancellationToken = default)
        => context.Friends.ReadOrDefaultAsync<FriendEdge>(Id(userId, friendUserId), new PartitionKey(userId), cancellationToken);

    public async Task UpsertAsync(FriendEdge edge, CancellationToken cancellationToken = default)
        => await context.Friends.UpsertItemAsync(edge, new PartitionKey(edge.UserId), cancellationToken: cancellationToken);

    public async Task RemoveAsync(string userId, string friendUserId, CancellationToken cancellationToken = default)
    {
        try
        {
            await context.Friends.DeleteItemAsync<FriendEdge>(Id(userId, friendUserId), new PartitionKey(userId), cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            // Already gone — removal is idempotent.
        }
    }

    private static string Id(string userId, string friendUserId) => $"{userId}:{friendUserId}";
}
