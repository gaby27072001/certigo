using System.Net;
using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;

namespace Certigo.Infrastructure.Cosmos;

/// Stores email/password credentials in the Users container, each in its own
/// partition (id = partition key = <c>credential::{emailLower}</c>). This reuses
/// the existing container — no new Cosmos container or Bicep change — while
/// staying isolated from profile documents (whose id is the userId).
public sealed class CosmosUserCredentialRepository(CosmosContext context) : IUserCredentialRepository
{
    public async Task<UserCredentialRecord?> FindByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(email);
        var legacyId = UserCredentialRecord.IdFor(normalized);
        var legacy = await context.Users.ReadOrDefaultAsync<UserCredentialRecord>(
            legacyId,
            new PartitionKey(legacyId),
            cancellationToken);
        return legacy
            ?? await FindByCanonicalEmailAsync(
                AuthRules.CanonicalizeEmail(normalized),
                cancellationToken);
    }

    public async Task<UserCredentialRecord?> FindByCanonicalEmailAsync(string canonicalEmail, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(canonicalEmail))
        {
            return null;
        }

        var canonicalId = UserCredentialRecord.CanonicalIdFor(canonicalEmail);
        var canonical = await context.Users.ReadOrDefaultAsync<UserCredentialRecord>(
            canonicalId,
            new PartitionKey(canonicalId),
            cancellationToken);
        if (canonical is not null)
        {
            return canonical;
        }

        // Compatibility lookup for credentials written before canonical ids were
        // introduced. New registrations never depend on this query for uniqueness:
        // their canonical CreateItem remains the atomic arbiter.
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

    public async Task<UserCredentialRecord> CreateAsync(UserCredentialRecord record, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await context.Users.CreateItemAsync(
                record,
                new PartitionKey(record.Id),
                cancellationToken: cancellationToken);
            return response.Resource;
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

    public async Task<bool> DeletePendingAsync(
        UserCredentialRecord record,
        CancellationToken cancellationToken = default)
    {
        if (!record.IsProvisioning || string.IsNullOrWhiteSpace(record.ETag))
        {
            return false;
        }

        try
        {
            await context.Users.DeleteItemAsync<UserCredentialRecord>(
                record.Id,
                new PartitionKey(record.Id),
                new ItemRequestOptions { IfMatchEtag = record.ETag },
                cancellationToken);
            return true;
        }
        catch (CosmosException ex) when (ex.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.PreconditionFailed)
        {
            return false;
        }
    }

    private static string Normalize(string email) => (email ?? string.Empty).Trim().ToLowerInvariant();
}
