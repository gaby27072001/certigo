using Microsoft.Azure.Cosmos;
using System.Net;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosAttemptRepository(CosmosContext context) : IAttemptRepository
{
    public async Task<AttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId AND c.clientAttemptId = @clientAttemptId")
            .WithParameter("@userId", userId)
            .WithParameter("@clientAttemptId", clientAttemptId);
        using var iterator = context.Attempts.GetItemQueryIterator<AttemptRecord>(query, requestOptions: new QueryRequestOptions
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

    public async Task CreateAsync(AttemptRecord attempt, CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            attempt.UserId,
            cancellationToken);
        // Atomic idempotency: the doc id is derived from the clientAttemptId, so a
        // duplicate (replayed or concurrent) submission fails the create instead of
        // double-applying. Surfaced as a domain-level DuplicateRecordException.
        await writeLease.MarkMutationDispatchedAsync();
        try
        {
            var response = await context.Attempts.CreateItemAsync(
                attempt,
                new PartitionKey(attempt.UserId),
                cancellationToken: cancellationToken);
            await writeLease.CommitAsync(
                CosmosContainers.Attempts,
                response.Headers.Session,
                cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            writeLease.MarkDefinitelyNotCommitted();
            throw new DuplicateRecordException($"Attempt '{attempt.Id}' already exists.");
        }
    }

    public async Task<RecentActivity> GetRecentActivityAsync(string userId, DateTimeOffset since, CancellationToken cancellationToken = default)
    {
        // Single mono-partition aggregate (PK = /userId). SUM over an empty set is
        // undefined in Cosmos, hence the nullable projection coalesced to 0.
        //
        // Contrainte Cosmos : les agrégats se projettent à plat, un par élément de
        // la liste SELECT. Les composer dans un littéral d'objet
        // (`SELECT VALUE { "a": COUNT(1), ... }`) est rejeté à l'exécution par
        // « Compositions of aggregates and other expressions are not allowed »,
        // ce qui remontait en HTTP 500 sur toute soumission de quiz et toute
        // génération d'examen — ce chemin est le garde-fou de cadence des deux.
        var query = new QueryDefinition(
                "SELECT COUNT(1) AS attempts, SUM(c.result.rewards.xpEarned) AS xp " +
                "FROM c WHERE c.userId = @userId AND c.submittedAt >= @since")
            .WithParameter("@userId", userId)
            .WithParameter("@since", since);
        using var iterator = context.Attempts.GetItemQueryIterator<RecentActivityRow>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(userId)
        });

        var attempts = 0;
        var xp = 0;
        while (iterator.HasMoreResults)
        {
            foreach (var row in await iterator.ReadNextAsync(cancellationToken))
            {
                attempts = row.Attempts;
                xp = row.Xp ?? 0;
            }
        }

        return new RecentActivity(attempts, xp);
    }

    private sealed record RecentActivityRow(int Attempts, int? Xp);
}
