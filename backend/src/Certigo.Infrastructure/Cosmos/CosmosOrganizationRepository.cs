using System.Net;
using Certigo.Application.Abstractions;
using Certigo.Domain.Organizations;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosOrganizationRepository(
    CosmosContext context,
    IEnterpriseLearningMetricReceiptRepository metricReceipts,
    IEnterpriseLearningReceiptOutboxRepository metricOutbox) : IOrganizationRepository
{
    private const int PurgePageSize = 50;
    private const int CompletedTombstoneTtlSeconds = 2_592_000;

    public async Task<OrganizationCreateResult> CreateOrganizationAsync(
        Organization organization,
        OrganizationMembership ownerMembership,
        CancellationToken cancellationToken = default)
    {
        EnsureSameOrganization(organization.OrganizationId, ownerMembership.OrganizationId);
        var partitionKey = new PartitionKey(organization.OrganizationId);
        using var response = await context.Organizations
            .CreateTransactionalBatch(partitionKey)
            .CreateItem(organization)
            .CreateItem(ownerMembership)
            .ExecuteAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return new OrganizationCreateResult(
                OrganizationCreateStatus.Created,
                response.GetOperationResultAtIndex<Organization>(0).Resource);
        }
        if (response.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await GetOrganizationAsync(
                organization.OrganizationId,
                cancellationToken)
                ?? throw new ConcurrencyConflictException(
                    "The organization was created concurrently but could not be reloaded.");
            return new OrganizationCreateResult(OrganizationCreateStatus.Replayed, existing);
        }
        throw CreateBatchException("Could not create the organization.", response);
    }

    public Task<Organization?> GetOrganizationAsync(
        string organizationId,
        CancellationToken cancellationToken = default) =>
        context.Organizations.ReadOrDefaultAsync<Organization>(
            organizationId,
            new PartitionKey(organizationId),
            cancellationToken);

    public Task<OrganizationMembership?> GetMembershipAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken = default) =>
        context.Organizations.ReadOrDefaultAsync<OrganizationMembership>(
            OrganizationDocumentIds.Membership(organizationId, personId),
            new PartitionKey(organizationId),
            cancellationToken);

    public Task<OrganizationInvitation?> GetInvitationAsync(
        string organizationId,
        string invitationId,
        CancellationToken cancellationToken = default) =>
        context.Organizations.ReadOrDefaultAsync<OrganizationInvitation>(
            invitationId,
            new PartitionKey(organizationId),
            cancellationToken);

    public async Task<OrganizationInvitationCreateResult> CreateInvitationAsync(
        OrganizationMembership actor,
        OrganizationInvitation invitation,
        CancellationToken cancellationToken = default)
    {
        EnsureAuthorizedActor(
            actor,
            invitation.OrganizationId,
            OrganizationAuthorization.CanInvite);
        var receipt = OrganizationInvitationReceipt.From(invitation);
        using var response = await context.Organizations
            .CreateTransactionalBatch(new PartitionKey(invitation.OrganizationId))
            .ReplaceItem(
                actor.Id,
                actor,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = actor.ETag })
            .CreateItem(receipt)
            .CreateItem(invitation)
            .ExecuteAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return new OrganizationInvitationCreateResult(
                OrganizationCreateStatus.Created,
                response.GetOperationResultAtIndex<OrganizationInvitation>(2).Resource);
        }
        if (response.StatusCode is HttpStatusCode.NotFound
            or HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException(
                "The inviting membership changed before the invitation was created.");
        }
        if (response.StatusCode == HttpStatusCode.Conflict)
        {
            var existingReceipt = await context.Organizations
                .ReadOrDefaultAsync<OrganizationInvitationReceipt>(
                    receipt.Id,
                    new PartitionKey(invitation.OrganizationId),
                    cancellationToken)
                ?? throw new ConcurrencyConflictException(
                    "The invitation receipt was created concurrently but could not be reloaded.");
            if (!string.Equals(
                    existingReceipt.CreationRequestHash,
                    invitation.CreationRequestHash,
                    StringComparison.Ordinal))
            {
                throw new OrganizationIdempotencyConflictException();
            }
            var existing = await GetInvitationAsync(
                invitation.OrganizationId,
                invitation.Id,
                cancellationToken)
                ?? throw new OrganizationInvitationReplayException();
            return new OrganizationInvitationCreateResult(
                OrganizationCreateStatus.Replayed,
                existing);
        }
        throw CreateBatchException("Could not create the organization invitation.", response);
    }

    public async Task<OrganizationMembership> AcceptInvitationAsync(
        OrganizationMembership issuer,
        OrganizationInvitation invitation,
        OrganizationMembership membership,
        CancellationToken cancellationToken = default)
    {
        EnsureSameOrganization(invitation.OrganizationId, membership.OrganizationId);
        EnsureAuthorizedActor(
            issuer,
            invitation.OrganizationId,
            OrganizationAuthorization.CanInvite);
        if (!string.Equals(
                issuer.PersonId,
                invitation.CreatedByPersonId,
                StringComparison.Ordinal))
        {
            throw new OrganizationAccessDeniedException();
        }
        if (string.IsNullOrWhiteSpace(invitation.ETag))
        {
            throw new OrganizationInvitationReplayException();
        }

        using var response = await context.Organizations
            .CreateTransactionalBatch(new PartitionKey(invitation.OrganizationId))
            .ReplaceItem(
                issuer.Id,
                issuer,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = issuer.ETag })
            .ReplaceItem(
                invitation.Id,
                invitation,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = invitation.ETag })
            .CreateItem(membership)
            .ExecuteAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return response.GetOperationResultAtIndex<OrganizationMembership>(2).Resource;
        }
        if (response.StatusCode == HttpStatusCode.NotFound
            && response[0].StatusCode == HttpStatusCode.NotFound)
        {
            throw new ConcurrencyConflictException(
                "The invitation issuer was offboarded before acceptance committed.");
        }
        if (response.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
        {
            throw new OrganizationInvitationReplayException();
        }
        throw CreateBatchException("Could not accept the organization invitation.", response);
    }

    public async Task<OrganizationTeamCreateResult> CreateTeamAsync(
        OrganizationMembership actor,
        OrganizationTeam team,
        CancellationToken cancellationToken = default)
    {
        EnsureAuthorizedActor(
            actor,
            team.OrganizationId,
            OrganizationAuthorization.CanManageTeams);
        using var response = await context.Organizations
            .CreateTransactionalBatch(new PartitionKey(team.OrganizationId))
            .ReplaceItem(
                actor.Id,
                actor,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = actor.ETag })
            .CreateItem(team)
            .ExecuteAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return new OrganizationTeamCreateResult(
                OrganizationCreateStatus.Created,
                response.GetOperationResultAtIndex<OrganizationTeam>(1).Resource);
        }
        if (response.StatusCode is HttpStatusCode.NotFound
            or HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException(
                "The managing membership changed before the team was created.");
        }
        if (response.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await GetTeamAsync(
                team.OrganizationId,
                team.Id,
                cancellationToken)
                ?? throw new ConcurrencyConflictException(
                    "The team was created concurrently but could not be reloaded.");
            return new OrganizationTeamCreateResult(OrganizationCreateStatus.Replayed, existing);
        }
        throw CreateBatchException("Could not create the organization team.", response);
    }

    public Task<OrganizationTeam?> GetTeamAsync(
        string organizationId,
        string teamId,
        CancellationToken cancellationToken = default) =>
        context.Organizations.ReadOrDefaultAsync<OrganizationTeam>(
            teamId,
            new PartitionKey(organizationId),
            cancellationToken);

    public async Task AddTeamMemberAsync(
        OrganizationMembership actor,
        OrganizationMembership target,
        OrganizationTeamMembership teamMembership,
        CancellationToken cancellationToken = default)
    {
        EnsureAuthorizedActor(
            actor,
            teamMembership.OrganizationId,
            OrganizationAuthorization.CanManageTeams);
        EnsureMembership(target, teamMembership.OrganizationId);

        var batch = context.Organizations
            .CreateTransactionalBatch(new PartitionKey(teamMembership.OrganizationId));
        batch.ReplaceItem(
            actor.Id,
            actor,
            new TransactionalBatchItemRequestOptions { IfMatchEtag = actor.ETag });
        if (!string.Equals(actor.Id, target.Id, StringComparison.Ordinal))
        {
            batch.ReplaceItem(
                target.Id,
                target,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = target.ETag });
        }
        using var response = await batch
            .CreateItem(teamMembership)
            .ExecuteAsync(cancellationToken);
        if (response.IsSuccessStatusCode || response.StatusCode == HttpStatusCode.Conflict)
        {
            return;
        }
        if (response.StatusCode is HttpStatusCode.NotFound
            or HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException(
                "The organization membership changed during the team assignment.");
        }
        throw CreateBatchException("Could not add the organization team member.", response);
    }

    public async Task OffboardAsync(
        OrganizationMembership actor,
        OrganizationMembership target,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken = default)
    {
        EnsureMembership(actor, target.OrganizationId);
        EnsureMembership(target, target.OrganizationId);
        if (target.Role == OrganizationRole.Owner)
        {
            throw new OrganizationOwnerOffboardingException();
        }
        var selfOffboarding = string.Equals(actor.Id, target.Id, StringComparison.Ordinal);
        if (!selfOffboarding && !OrganizationAuthorization.CanRemove(actor.Role, target.Role))
        {
            throw new OrganizationAccessDeniedException();
        }

        var tombstone = OrganizationOffboardingTombstone.Create(target, revokedAt);
        var batch = context.Organizations.CreateTransactionalBatch(
            new PartitionKey(target.OrganizationId));
        if (!selfOffboarding)
        {
            batch.ReplaceItem(
                actor.Id,
                actor,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = actor.ETag });
        }
        batch.CreateItem(tombstone)
            .DeleteItem(
                target.Id,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = target.ETag });
        using var response = await batch.ExecuteAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            if (response.StatusCode is HttpStatusCode.NotFound
                or HttpStatusCode.PreconditionFailed)
            {
                throw new ConcurrencyConflictException(
                    "The organization membership changed during offboarding.");
            }
            throw CreateBatchException("Could not offboard the organization member.", response);
        }

        await PurgeOffboardingAsync(
            target.OrganizationId,
            tombstone.Id,
            cancellationToken);
    }

    public async Task PurgeOffboardingAsync(
        string organizationId,
        string tombstoneId,
        CancellationToken cancellationToken = default)
    {
        var tombstone = await context.Organizations
            .ReadOrDefaultAsync<OrganizationOffboardingTombstone>(
                tombstoneId,
                new PartitionKey(organizationId),
                cancellationToken)
            ?? throw new ConcurrencyConflictException(
                "The offboarding tombstone could not be reloaded.");
        if (!string.Equals(tombstone.OrganizationId, organizationId, StringComparison.Ordinal))
        {
            throw new OrganizationNotFoundException();
        }
        if (tombstone.PurgeCompletedAt is not null)
        {
            return;
        }
        if (!await metricOutbox.IsSubjectDrainedAsync(
                organizationId,
                tombstone.MetricSubjectId,
                cancellationToken))
        {
            throw new ConcurrencyConflictException(
                "Receipt intents must drain before offboarding purge can complete.");
        }
        await PurgeByQueryAsync(
            organizationId,
            new QueryDefinition(
                    "SELECT TOP 50 VALUE c.id FROM c "
                    + "WHERE c.documentType = @type AND c.membershipId = @membershipId")
                .WithParameter("@type", OrganizationTeamMembership.Type)
                .WithParameter("@membershipId", tombstone.TargetMembershipId),
            cancellationToken);
        await PurgeByQueryAsync(
            organizationId,
            new QueryDefinition(
                    "SELECT TOP 50 VALUE c.id FROM c WHERE c.metricSubjectId = @metricSubjectId "
                    + "AND c.documentType = @leaseType")
                .WithParameter("@metricSubjectId", tombstone.MetricSubjectId)
                .WithParameter("@leaseType", EnterpriseLearningSessionLease.Type),
            cancellationToken);
        await metricReceipts.PurgeSubjectPartitionsAsync(
            tombstone.ReceiptPartitionKeys,
            tombstone.MetricSubjectId,
            cancellationToken);

        var completedAt = DateTimeOffset.UtcNow;
        try
        {
            await context.Organizations.ReplaceItemAsync(
                tombstone with
                {
                    PurgeCompletedAt = completedAt,
                    Ttl = CompletedTombstoneTtlSeconds,
                },
                tombstone.Id,
                new PartitionKey(organizationId),
                new ItemRequestOptions { IfMatchEtag = tombstone.ETag },
                cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
        {
            var completed = await context.Organizations
                .ReadOrDefaultAsync<OrganizationOffboardingTombstone>(
                    tombstone.Id,
                    new PartitionKey(organizationId),
                    cancellationToken);
            if (completed?.PurgeCompletedAt is null)
            {
                throw new ConcurrencyConflictException(
                    "The offboarding purge state changed concurrently.");
            }
        }
    }

    public async Task<OrganizationOffboardingTombstone?> GetLatestOffboardingAsync(
            string organizationId,
            string personId,
            CancellationToken cancellationToken = default)
        {
            var query = new QueryDefinition(
                    "SELECT TOP 1 * FROM c WHERE c.documentType = @type "
                    + "AND c.targetMembershipId = @membershipId ORDER BY c.membershipCycle DESC")
                .WithParameter("@type", OrganizationOffboardingTombstone.Type)
                .WithParameter(
                    "@membershipId",
                    OrganizationDocumentIds.Membership(organizationId, personId));
            using var iterator = context.Organizations
                .GetItemQueryIterator<OrganizationOffboardingTombstone>(
                    query,
                    requestOptions: new QueryRequestOptions
                    {
                        PartitionKey = new PartitionKey(organizationId),
                        MaxItemCount = 1,
                    });
            if (!iterator.HasMoreResults)
            {
                return null;
            }
            return (await iterator.ReadNextAsync(cancellationToken)).SingleOrDefault();
        }

    public async Task<IReadOnlyList<OrganizationOffboardingTombstone>>
        ListIncompleteOffboardingsAsync(
                int maximumTombstones,
                CancellationToken cancellationToken = default)
        {
            if (maximumTombstones is < 1 or > 100)
            {
                throw new ArgumentOutOfRangeException(nameof(maximumTombstones));
            }
            var query = new QueryDefinition(
                    "SELECT TOP @maximum * FROM c WHERE c.documentType = @type "
                    + "AND (NOT IS_DEFINED(c.purgeCompletedAt) OR IS_NULL(c.purgeCompletedAt))")
                .WithParameter("@maximum", maximumTombstones)
                .WithParameter("@type", OrganizationOffboardingTombstone.Type);
            using var iterator = context.Organizations
                .GetItemQueryIterator<OrganizationOffboardingTombstone>(
                    query,
                    requestOptions: new QueryRequestOptions
                    {
                        MaxItemCount = maximumTombstones,
                    });
            return iterator.HasMoreResults
                ? (await iterator.ReadNextAsync(cancellationToken)).ToArray()
                : [];
    }

    private async Task<IReadOnlyList<OrganizationTeamMembership>> ListTeamMembershipsAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.documentType = @type AND c.personId = @personId")
            .WithParameter("@type", OrganizationTeamMembership.Type)
            .WithParameter("@personId", personId);
        using var iterator = context.Organizations
            .GetItemQueryIterator<OrganizationTeamMembership>(
                query,
                requestOptions: new QueryRequestOptions
                {
                    PartitionKey = new PartitionKey(organizationId),
                });
        var results = new List<OrganizationTeamMembership>();
        while (iterator.HasMoreResults)
        {
            results.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }
        return results;
    }

    private async Task PurgeByQueryAsync(
        string organizationId,
        QueryDefinition query,
        CancellationToken cancellationToken)
    {
        var partitionKey = new PartitionKey(organizationId);
        while (true)
        {
            using var iterator = context.Organizations.GetItemQueryIterator<string>(
                query,
                requestOptions: new QueryRequestOptions
                {
                    PartitionKey = partitionKey,
                    MaxItemCount = PurgePageSize,
                });
            var ids = iterator.HasMoreResults
                ? (await iterator.ReadNextAsync(cancellationToken)).ToArray()
                : [];
            if (ids.Length == 0)
            {
                return;
            }
            foreach (var id in ids)
            {
                try
                {
                    await context.Organizations.DeleteItemAsync<object>(
                        id,
                        partitionKey,
                        cancellationToken: cancellationToken);
                }
                catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
                {
                    // A prior purge attempt already removed the page item.
                }
            }
        }
    }

    private static void EnsureSameOrganization(string left, string right)
    {
        if (!string.Equals(left, right, StringComparison.Ordinal))
        {
            throw new OrganizationValidationException(
                "Transactional organization documents must share a partition.");
        }
    }

    private static void EnsureAuthorizedActor(
        OrganizationMembership actor,
        string organizationId,
        Func<OrganizationRole, bool> authorize)
    {
        EnsureMembership(actor, organizationId);
        if (!authorize(actor.Role))
        {
            throw new OrganizationAccessDeniedException();
        }
    }

    private static void EnsureMembership(
        OrganizationMembership membership,
        string organizationId)
    {
        EnsureSameOrganization(membership.OrganizationId, organizationId);
        if (string.IsNullOrWhiteSpace(membership.ETag))
        {
            throw new ConcurrencyConflictException(
                "The organization membership has no concurrency token.");
        }
    }

    private static CosmosException CreateBatchException(
        string message,
        TransactionalBatchResponse response) =>
        new(
            message,
            response.StatusCode,
            0,
            response.ActivityId,
            response.RequestCharge);
}
