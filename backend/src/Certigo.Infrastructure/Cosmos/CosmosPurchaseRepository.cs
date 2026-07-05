using Microsoft.Azure.Cosmos;
using System.Net;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosPurchaseRepository(CosmosContext context) : IPurchaseRepository
{
    public async Task<PurchaseRecord?> GetByClientPurchaseIdAsync(string userId, string clientPurchaseId, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId AND c.clientPurchaseId = @clientPurchaseId")
            .WithParameter("@userId", userId)
            .WithParameter("@clientPurchaseId", clientPurchaseId);
        using var iterator = context.Economy.GetItemQueryIterator<PurchaseRecord>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(userId),
            MaxItemCount = 1
        });

        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            return page.FirstOrDefault();
        }

        return null;
    }

    public async Task CreateAsync(PurchaseRecord record, CancellationToken cancellationToken = default)
    {
        // Atomic idempotency on the clientPurchaseId-derived id so a replayed or
        // concurrent purchase can never debit gems twice.
        try
        {
            await context.Economy.CreateItemAsync(record, new PartitionKey(record.UserId), cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            throw new DuplicateRecordException($"Purchase '{record.Id}' already exists.");
        }
    }
}
