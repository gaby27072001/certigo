using Microsoft.Azure.Cosmos;
using System.Net;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Progress;

namespace Microlingo.Infrastructure.Cosmos;

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
        var response = await context.Users.UpsertItemAsync(profile, new PartitionKey(profile.Id), cancellationToken: cancellationToken);
        return response.Resource;
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
        => await context.Attempts.CreateItemAsync(attempt, new PartitionKey(attempt.UserId), cancellationToken: cancellationToken);
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
        => await context.Attempts.CreateItemAsync(attempt, new PartitionKey(attempt.UserId), cancellationToken: cancellationToken);
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
        var existing = await context.Leaderboard.ReadOrDefaultAsync<LeaderboardEntryDocument>(id, new PartitionKey(periodLeagueId), cancellationToken);
        var updated = (existing ?? new LeaderboardEntryDocument(id, periodLeagueId, userId, displayName, avatarUrl, 0)) with
        {
            DisplayName = displayName,
            AvatarUrl = avatarUrl,
            Xp = (existing?.Xp ?? 0) + xp
        };
        await context.Leaderboard.UpsertItemAsync(updated, new PartitionKey(periodLeagueId), cancellationToken: cancellationToken);
    }

    private sealed record LeaderboardEntryDocument(string Id, string PeriodLeagueId, string UserId, string DisplayName, string? AvatarUrl, int Xp);
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
        => await context.Economy.CreateItemAsync(record, new PartitionKey(record.UserId), cancellationToken: cancellationToken);
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
