using System.Net;
using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

/// Stores email/password credentials in the Users container, each in its own
/// partition (id = partition key = <c>credential::{emailLower}</c>). This reuses
/// the existing container — no new Cosmos container or Bicep change — while
/// staying isolated from profile documents (whose id is the userId).
public sealed class CosmosUserCredentialRepository(CosmosContext context) : IUserCredentialRepository
{
    public Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        var id = UserCredentialRecord.IdFor(Normalize(email));
        return context.Users.ReadOrDefaultAsync<UserCredentialRecord>(id, new PartitionKey(id), cancellationToken);
    }

    public async Task<UserCredentialRecord?> FindByCanonicalEmailAsync(string canonicalEmail, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(canonicalEmail))
        {
            return null;
        }

        // Cross-partition query (credential docs are keyed by id = the exact email),
        // hit only on register and login misses — never on the hot login path. The
        // type discriminator keeps it isolated from profile documents that share
        // the Users container.
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.type = 'credential' AND c.canonicalEmail = @canonical")
            .WithParameter("@canonical", canonicalEmail);

        using var iterator = context.Users.GetItemQueryIterator<UserCredentialRecord>(query);
        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            var match = page.FirstOrDefault();
            if (match is not null)
            {
                return match;
            }
        }

        return null;
    }

    public async Task CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        try
        {
            await context.Users.CreateItemAsync(record, new PartitionKey(record.Id), cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            throw new DuplicateRecordException($"A credential for '{record.Email}' already exists.");
        }
    }

    public async Task UpdateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(record.ETag))
        {
            throw new InvalidOperationException($"Credential '{record.Id}' update requires an ETag.");
        }

        try
        {
            await context.Users.ReplaceItemAsync(
                record,
                record.Id,
                new PartitionKey(record.Id),
                new ItemRequestOptions { IfMatchEtag = record.ETag },
                cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException($"Credential '{record.Id}' was modified concurrently.");
        }
    }

    private static string Normalize(string email) => (email ?? string.Empty).Trim().ToLowerInvariant();
}
