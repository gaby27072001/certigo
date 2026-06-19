using System.Net;
using Microsoft.Azure.Cosmos;

namespace Microlingo.Infrastructure.Cosmos;

internal static class CosmosExtensions
{
    public static async Task<T?> ReadOrDefaultAsync<T>(
        this Container container,
        string id,
        PartitionKey partitionKey,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await container.ReadItemAsync<T>(id, partitionKey, cancellationToken: cancellationToken);
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            return default;
        }
    }
}
