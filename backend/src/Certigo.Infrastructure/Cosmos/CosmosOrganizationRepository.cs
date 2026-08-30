using System.Net;
using Certigo.Application.Abstractions;
using Certigo.Domain.Organizations;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosOrganizationRepository(CosmosContext context) : IOrganizationRepository
{
    private const int MaximumBatchOperations = 100;

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

        var teamEdges = await ListTeamMembershipsAsync(
            target.OrganizationId,
            target.PersonId,
            cancellationToken);
        var operationCount = teamEdges.Count + (selfOffboarding ? 1 : 2);
        if (operationCount > MaximumBatchOperations)
        {
            throw new ConcurrencyConflictException(
                "The membership has too many team assignments for atomic offboarding.");
        }

        var batch = context.Organizations.CreateTransactionalBatch(
            new PartitionKey(target.OrganizationId));
        if (!selfOffboarding)
        {
            batch.ReplaceItem(
                actor.Id,
                actor,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = actor.ETag });
        }
        foreach (var edge in teamEdges)
        {
            batch.DeleteItem(edge.Id);
        }
        batch.DeleteItem(
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
