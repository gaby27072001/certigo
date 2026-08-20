using System.Net;
using Certigo.Application.Abstractions;
using Certigo.Domain.Identity;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosPersonLinkedIdentityRepository(CosmosContext context)
    : IPersonLinkedIdentityRepository
{
    private const int MaximumConcurrencyAttempts = 5;

    public async Task<LinkedIdentity?> GetAsync(
        IdentityLocator locator,
        CancellationToken cancellationToken = default)
    {
        var canonical = locator.EnsureCanonical();
        var id = canonical.StableId();
        var existing = await context.Users.ReadOrDefaultAsync<LinkedIdentity>(
            id,
            new PartitionKey(id),
            cancellationToken);
        if (existing is null)
        {
            return null;
        }

        EnsureMatchingLocator(existing, canonical);
        existing.EnsureValid();
        return existing;
    }

    public async Task<LinkedIdentityCreateResult> CreateOrReadAsync(
        LinkedIdentity identity,
        CancellationToken cancellationToken = default)
    {
        identity.EnsureValid();
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            identity.PersonId,
            cancellationToken);
        await writeLease.MarkMutationDispatchedAsync();
        try
        {
            var response = await context.Users.CreateItemAsync(
                identity,
                new PartitionKey(identity.Id),
                cancellationToken: cancellationToken);
            await writeLease.CommitAsync(
                CosmosContainers.Users,
                response.Headers.Session,
                cancellationToken);
            return new LinkedIdentityCreateResult(
                LinkedIdentityCreateStatus.Created,
                response.Resource);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            writeLease.MarkDefinitelyNotCommitted();
            var existing = await context.Users.ReadOrDefaultAsync<LinkedIdentity>(
                identity.Id,
                new PartitionKey(identity.Id),
                cancellationToken)
                ?? throw new ConcurrencyConflictException(
                    "The identity mirror was created concurrently but could not be reloaded.");
            EnsureMatchingLocator(existing, identity.Locator);
            if (!string.Equals(existing.PersonId, identity.PersonId, StringComparison.Ordinal))
            {
                throw new IdentityAlreadyLinkedException();
            }

            existing.EnsureValid();
            return new LinkedIdentityCreateResult(
                LinkedIdentityCreateStatus.Replayed,
                existing);
        }
        catch (CosmosException ex) when (
            ex.StatusCode is HttpStatusCode.BadRequest
                or HttpStatusCode.Unauthorized
                or HttpStatusCode.Forbidden
                or HttpStatusCode.RequestEntityTooLarge)
        {
            writeLease.MarkDefinitelyNotCommitted();
            throw new DefinitivePersistenceException(
                "The identity mirror was rejected before commit.",
                ex);
        }
    }

    public async Task<IReadOnlyList<LinkedIdentity>> ListByPersonAsync(
        string personId,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(personId);
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.documentType = @documentType AND c.personId = @personId")
            .WithParameter("@documentType", LinkedIdentity.LinkedIdentityDocumentType)
            .WithParameter("@personId", personId);
        using var iterator = context.Users.GetItemQueryIterator<LinkedIdentity>(query);
        var results = new List<LinkedIdentity>();
        while (iterator.HasMoreResults)
        {
            results.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        foreach (var identity in results)
        {
            identity.EnsureValid();
            if (!string.Equals(identity.PersonId, personId, StringComparison.Ordinal))
            {
                throw new PersonIdentityIntegrityException();
            }
        }

        return results;
    }

    public async Task<AccountDeletionIdentityCleanupResult> CleanupForAccountDeletionAsync(
        string personId,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken = default)
    {
        var tombstoned = 0;
        foreach (var identity in await ListByPersonAsync(personId, cancellationToken))
        {
            if (await TombstoneAsync(identity, personId, revokedAt, cancellationToken))
            {
                tombstoned++;
            }
        }

        var deletedJournals = await DeleteTransientJournalsAsync(
            personId,
            cancellationToken);
        return new AccountDeletionIdentityCleanupResult(tombstoned, deletedJournals);
    }

    private async Task<bool> TombstoneAsync(
        LinkedIdentity initial,
        string personId,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken)
    {
        var current = initial;
        for (var attempt = 1; attempt <= MaximumConcurrencyAttempts; attempt++)
        {
            if (!string.Equals(current.PersonId, personId, StringComparison.Ordinal))
            {
                throw new PersonIdentityIntegrityException();
            }
            if (current.Revocation.State == LinkedIdentityRevocation.RevokedState)
            {
                return false;
            }
            if (string.IsNullOrWhiteSpace(current.ETag))
            {
                throw new PersonIdentityIntegrityException();
            }

            var tombstone = current with
            {
                Revocation = current.Revocation with
                {
                    State = LinkedIdentityRevocation.RevokedState,
                    Generation = checked(current.Revocation.Generation + 1),
                    ProviderAction = LinkedIdentityRevocation.NotRequestedProviderAction,
                    RevokedAt = revokedAt,
                    Reason = LinkedIdentityRevocation.AccountDeletionReason,
                    OperationId = null,
                },
                UpdatedAt = revokedAt,
            };
            try
            {
                await context.Users.ReplaceItemAsync(
                    tombstone,
                    current.Id,
                    new PartitionKey(current.Id),
                    new ItemRequestOptions { IfMatchEtag = current.ETag },
                    cancellationToken);
                return true;
            }
            catch (CosmosException ex) when (
                ex.StatusCode == HttpStatusCode.PreconditionFailed
                && attempt < MaximumConcurrencyAttempts)
            {
                current = await context.Users.ReadOrDefaultAsync<LinkedIdentity>(
                    current.Id,
                    new PartitionKey(current.Id),
                    cancellationToken)
                    ?? throw new PersonIdentityIntegrityException();
                EnsureMatchingLocator(current, initial.Locator);
            }
        }

        throw new ConcurrencyConflictException(
            "The LinkedIdentity tombstone changed repeatedly during account deletion.");
    }

    private async Task<int> DeleteTransientJournalsAsync(
        string personId,
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT c.id, c.documentType FROM c "
                + "WHERE c.personId = @personId "
                + "AND (c.documentType = @intentType OR c.documentType = @operationType)")
            .WithParameter("@personId", personId)
            .WithParameter(
                "@intentType",
                IdentityLinkIntent.IdentityLinkIntentDocumentType)
            .WithParameter(
                "@operationType",
                IdentityLinkOperation.IdentityLinkOperationDocumentType);
        using var iterator = context.Users.GetItemQueryIterator<IdentityJournalReference>(query);
        var journals = new List<IdentityJournalReference>();
        while (iterator.HasMoreResults)
        {
            journals.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        var deleted = 0;
        foreach (var journal in journals)
        {
            try
            {
                await context.Users.DeleteItemAsync<object>(
                    journal.Id,
                    new PartitionKey(journal.Id),
                    cancellationToken: cancellationToken);
                deleted++;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
            {
                // An account-deletion replay or concurrent cleanup already removed it.
            }
        }

        return deleted;
    }

    private static void EnsureMatchingLocator(
        LinkedIdentity existing,
        IdentityLocator expected)
    {
        try
        {
            if (existing.Locator.EnsureCanonical() != expected.EnsureCanonical())
            {
                throw new IdentityHashCollisionException();
            }
        }
        catch (InvalidIdentityLocatorException)
        {
            throw new IdentityHashCollisionException();
        }
    }

    private sealed record IdentityJournalReference(string Id, string DocumentType);
}
