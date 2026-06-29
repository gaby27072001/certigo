using Microsoft.Azure.Cosmos;
using System.Net;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Certigo.Domain.Gamification;
using Certigo.Domain.Progress;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosUserRepository(CosmosContext context) : IUserRepository
{
    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
        => context.Users.ReadOrDefaultAsync<UserProfileDto>(userId, new PartitionKey(userId), cancellationToken);

    public async Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default)
    {
        // Cross-partition lookup; rare (only on a friend-add) so the fan-out cost
        // is acceptable. Handles are slugified at provisioning time.
        var query = new QueryDefinition("SELECT TOP 1 * FROM c WHERE c.handle = @handle")
            .WithParameter("@handle", handle);
        using var iterator = context.Users.GetItemQueryIterator<UserProfileDto>(query);
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

    public async Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default)
    {
        // Honour the optimistic-concurrency token when present so two concurrent
        // economy mutations (e.g. a quiz submit and a shop purchase) can't clobber
        // each other; a 412 surfaces as a domain-level ConcurrencyConflictException.
        var options = string.IsNullOrEmpty(profile.ETag)
            ? null
            : new ItemRequestOptions { IfMatchEtag = profile.ETag };
        try
        {
            var response = await context.Users.UpsertItemAsync(profile, new PartitionKey(profile.Id), options, cancellationToken);
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException($"User profile '{profile.Id}' was modified concurrently.");
        }
    }
}

public sealed class CosmosContentRepository(CosmosContext context) : IContentRepository
{
    public Task<Track?> GetTrackAsync(string trackId, CancellationToken cancellationToken = default)
        => context.Content.ReadOrDefaultAsync<Track>(trackId, new PartitionKey(trackId), cancellationToken);

    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => context.Content.ReadOrDefaultAsync<Lesson>(lessonId, new PartitionKey(trackId), cancellationToken);

    public Task<LessonAnswerKey?> GetAnswerKeyAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => context.Content.ReadOrDefaultAsync<LessonAnswerKey>($"answerkey::{lessonId}", new PartitionKey(trackId), cancellationToken);

    public async Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(string trackId, CancellationToken cancellationToken = default)
    {
        // Answer-key docs are id="answerkey::{lessonId}", PK=/trackId; STARTSWITH
        // isolates them from the track and lesson documents in the same partition.
        var query = new QueryDefinition("SELECT * FROM c WHERE c.trackId = @trackId AND STARTSWITH(c.id, 'answerkey::')")
            .WithParameter("@trackId", trackId);
        using var iterator = context.Content.GetItemQueryIterator<LessonAnswerKey>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(trackId)
        });

        var keys = new List<LessonAnswerKey>();
        while (iterator.HasMoreResults)
        {
            keys.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        return keys;
    }

    public async Task<IReadOnlyList<Track>> ListTracksAsync(CancellationToken cancellationToken = default)
    {
        // Track docs are seeded with type="track" (id == trackId), one per
        // /trackId partition, so this is a deliberate cross-partition scan with
        // NO PartitionKey — the catalog spans every track.
        var query = new QueryDefinition("SELECT * FROM c WHERE c.type = 'track'");
        using var iterator = context.Content.GetItemQueryIterator<Track>(query);

        var tracks = new List<Track>();
        while (iterator.HasMoreResults)
        {
            tracks.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        return tracks;
    }
}

public sealed class CosmosProgressRepository(CosmosContext context) : IProgressRepository
{
    public async Task<ConceptMastery?> GetMasteryAsync(string userId, string trackId, string conceptId, CancellationToken cancellationToken = default)
    {
        var doc = await context.Progress.ReadOrDefaultAsync<ConceptMasteryDocument>(
            Id(trackId, conceptId),
            new PartitionKey(userId),
            cancellationToken);
        return doc?.Mastery;
    }

    public async Task<IReadOnlyList<ConceptMastery>> ListMasteriesAsync(string userId, string trackId, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId AND c.trackId = @trackId")
            .WithParameter("@userId", userId)
            .WithParameter("@trackId", trackId);
        using var iterator = context.Progress.GetItemQueryIterator<ConceptMasteryDocument>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(userId)
        });

        var masteries = new List<ConceptMastery>();
        while (iterator.HasMoreResults)
        {
            foreach (var doc in await iterator.ReadNextAsync(cancellationToken))
            {
                if (doc.Mastery is not null)
                {
                    masteries.Add(doc.Mastery);
                }
            }
        }

        return masteries;
    }

    public async Task UpsertMasteryBatchAsync(string userId, IReadOnlyList<ConceptMastery> masteries, CancellationToken cancellationToken = default)
    {
        if (masteries.Count == 0)
        {
            return;
        }

        var batch = context.Progress.CreateTransactionalBatch(new PartitionKey(userId));
        foreach (var mastery in masteries)
        {
            batch.UpsertItem(new ConceptMasteryDocument(Id(mastery.TrackId, mastery.ConceptId), userId, mastery.TrackId, mastery.ConceptId, mastery));
        }

        using var response = await batch.ExecuteAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new CosmosException($"Progress batch failed: {response.StatusCode}", response.StatusCode, 0, response.ActivityId, response.RequestCharge);
        }
    }

    private static string Id(string trackId, string conceptId) => $"{trackId}:{conceptId}";

    private sealed record ConceptMasteryDocument(string Id, string UserId, string TrackId, string ConceptId, ConceptMastery Mastery);
}

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
        // Atomic idempotency: the doc id is derived from the clientAttemptId, so a
        // duplicate (replayed or concurrent) submission fails the create instead of
        // double-applying. Surfaced as a domain-level DuplicateRecordException.
        try
        {
            await context.Attempts.CreateItemAsync(attempt, new PartitionKey(attempt.UserId), cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            throw new DuplicateRecordException($"Attempt '{attempt.Id}' already exists.");
        }
    }

    public async Task<RecentActivity> GetRecentActivityAsync(string userId, DateTimeOffset since, CancellationToken cancellationToken = default)
    {
        // Single mono-partition aggregate (PK = /userId). SUM over an empty set is
        // undefined in Cosmos, hence the nullable projection coalesced to 0.
        var query = new QueryDefinition(
                "SELECT VALUE { \"attempts\": COUNT(1), \"xp\": SUM(c.result.rewards.xpEarned) } " +
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

public sealed class CosmosExamAttemptRepository(CosmosContext context) : IExamAttemptRepository
{
    public async Task<ExamAttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default)
    {
        // Shares the attempts container with lesson attempts; the kind = 'exam'
        // filter keeps the two record shapes from colliding on idempotency lookups.
        var query = new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId AND c.clientAttemptId = @clientAttemptId AND c.kind = 'exam'")
            .WithParameter("@userId", userId)
            .WithParameter("@clientAttemptId", clientAttemptId);
        using var iterator = context.Attempts.GetItemQueryIterator<ExamAttemptRecord>(query, requestOptions: new QueryRequestOptions
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

    public async Task CreateAsync(ExamAttemptRecord attempt, CancellationToken cancellationToken = default)
    {
        try
        {
            await context.Attempts.CreateItemAsync(attempt, new PartitionKey(attempt.UserId), cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            throw new DuplicateRecordException($"Exam attempt '{attempt.Id}' already exists.");
        }
    }
}

public sealed class CosmosEventRepository(CosmosContext context) : IEventRepository
{
    public async Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default)
        => await context.Events.CreateItemAsync(learningEvent, new PartitionKey(learningEvent.UserId), cancellationToken: cancellationToken);
}

public sealed class CosmosLeaderboardRepository(CosmosContext context) : ILeaderboardRepository
{
    private const string Tier = "bronze";
    private const int PromoteCount = 10;

    public async Task<LeagueDto> GetLeagueAsync(string userId, CancellationToken cancellationToken = default)
    {
        var period = LeaguePeriods.ForInstant(DateTimeOffset.UtcNow);
        var periodLeagueId = period.Compose(Tier);
        var query = new QueryDefinition("SELECT TOP 50 * FROM c WHERE c.periodLeagueId = @periodLeagueId ORDER BY c.xp DESC")
            .WithParameter("@periodLeagueId", periodLeagueId);
        using var iterator = context.Leaderboard.GetItemQueryIterator<LeaderboardEntryDocument>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(periodLeagueId)
        });
        var entries = new List<LeaderboardEntryDto>();
        var rank = 1;
        while (iterator.HasMoreResults)
        {
            foreach (var entry in await iterator.ReadNextAsync(cancellationToken))
            {
                entries.Add(new LeaderboardEntryDto(entry.UserId, entry.DisplayName, entry.AvatarUrl, rank++, entry.Xp));
            }
        }

        return new LeagueDto(periodLeagueId, Tier, period.EndsAt, PromoteCount, userId, entries);
    }

    public async Task AddXpAsync(string userId, int xp, CancellationToken cancellationToken = default)
    {
        var periodLeagueId = LeaguePeriods.ForInstant(DateTimeOffset.UtcNow).Compose(Tier);
        var id = $"{periodLeagueId}:{userId}";
        var profile = await context.Users.ReadOrDefaultAsync<UserProfileDto>(userId, new PartitionKey(userId), cancellationToken);
        var displayName = profile?.DisplayName ?? userId;
        var avatarUrl = profile?.AvatarUrl;
        var partitionKey = new PartitionKey(periodLeagueId);

        for (var attempt = 1; attempt <= 3; attempt++)
        {
            var existing = await context.Leaderboard.ReadOrDefaultAsync<LeaderboardEntryDocument>(id, partitionKey, cancellationToken);
            var updated = (existing ?? new LeaderboardEntryDocument(id, periodLeagueId, userId, displayName, avatarUrl, 0)) with
            {
                DisplayName = displayName,
                AvatarUrl = avatarUrl,
                Xp = (existing?.Xp ?? 0) + xp
            };

            try
            {
                if (existing is null)
                {
                    await context.Leaderboard.CreateItemAsync(updated, partitionKey, cancellationToken: cancellationToken);
                }
                else
                {
                    await context.Leaderboard.ReplaceItemAsync(
                        updated,
                        id,
                        partitionKey,
                        new ItemRequestOptions { IfMatchEtag = existing.ETag },
                        cancellationToken);
                }

                return;
            }
            catch (CosmosException ex) when (attempt < 3 && ex.StatusCode is HttpStatusCode.PreconditionFailed or HttpStatusCode.Conflict)
            {
                // Concurrent writer won this round; re-read and retry with fresh ETag.
            }
        }

        throw new ConcurrencyConflictException($"Leaderboard entry '{id}' was modified concurrently.");
    }

    private sealed record LeaderboardEntryDocument(string Id, string PeriodLeagueId, string UserId, string DisplayName, string? AvatarUrl, int Xp)
    {
        [JsonPropertyName("_etag")]
        public string? ETag { get; init; }
    }
}

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

// The tutor's per-(user, track) memory. Reuses the progress container (PK =
// /userId) under a "learnermodel::{trackId}" id, so it adds no container and no
// Bicep change. The track is stored as "track" (not "trackId") so the concept-
// mastery query in CosmosProgressRepository never picks these documents up.
public sealed class CosmosLearnerModelRepository(CosmosContext context) : ILearnerModelRepository
{
    public async Task<LearnerModelRecord?> GetAsync(string userId, string trackId, CancellationToken cancellationToken = default)
    {
        var doc = await context.Progress.ReadOrDefaultAsync<LearnerModelDocument>(
            Id(trackId), new PartitionKey(userId), cancellationToken);
        return doc?.Model;
    }

    public async Task UpsertAsync(LearnerModelRecord model, CancellationToken cancellationToken = default)
    {
        var doc = new LearnerModelDocument(Id(model.TrackId), model.UserId, model.TrackId, model);
        await context.Progress.UpsertItemAsync(doc, new PartitionKey(model.UserId), cancellationToken: cancellationToken);
    }

    private static string Id(string trackId) => $"learnermodel::{trackId}";

    private sealed record LearnerModelDocument(string Id, string UserId, string Track, LearnerModelRecord Model);
}
