using Microsoft.Azure.Cosmos;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Progress;

namespace Microlingo.Infrastructure.Cosmos;

public sealed class CosmosUserRepository(CosmosContext context) : IUserRepository
{
    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
        => context.Users.ReadOrDefaultAsync<UserProfileDto>(userId, new PartitionKey(userId), cancellationToken);

    public async Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default)
    {
        var response = await context.Users.UpsertItemAsync(profile, new PartitionKey(profile.Id), cancellationToken: cancellationToken);
        return response.Resource;
    }
}

public sealed class CosmosContentRepository(CosmosContext context) : IContentRepository
{
    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => context.Content.ReadOrDefaultAsync<Lesson>(lessonId, new PartitionKey(trackId), cancellationToken);

    public async Task<IReadOnlyList<QuizItem>> GetItemsAsync(string trackId, IReadOnlyList<string> ids, CancellationToken cancellationToken = default)
    {
        var reads = ids.Select(id => context.Content.ReadOrDefaultAsync<QuizItem>(id, new PartitionKey(trackId), cancellationToken));
        var items = await Task.WhenAll(reads);
        return items.Where(i => i is not null).Cast<QuizItem>().ToArray();
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

public sealed class CosmosEventRepository(CosmosContext context) : IEventRepository
{
    public async Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default)
        => await context.Events.CreateItemAsync(learningEvent, new PartitionKey(learningEvent.UserId), cancellationToken: cancellationToken);
}

public sealed class CosmosLeaderboardRepository(CosmosContext context) : ILeaderboardRepository
{
    public async Task<LeagueDto> GetLeagueAsync(string userId, CancellationToken cancellationToken = default)
    {
        var periodLeagueId = $"weekly:{DateOnly.FromDateTime(DateTime.UtcNow):yyyyMMdd}:bronze";
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
                entries.Add(new LeaderboardEntryDto(entry.UserId, entry.DisplayName, entry.Xp, rank++));
            }
        }

        return new LeagueDto(periodLeagueId, "Bronze", entries);
    }

    public async Task AddXpAsync(string userId, int xp, CancellationToken cancellationToken = default)
    {
        var periodLeagueId = $"weekly:{DateOnly.FromDateTime(DateTime.UtcNow):yyyyMMdd}:bronze";
        var id = $"{periodLeagueId}:{userId}";
        var existing = await context.Leaderboard.ReadOrDefaultAsync<LeaderboardEntryDocument>(id, new PartitionKey(periodLeagueId), cancellationToken);
        var updated = (existing ?? new LeaderboardEntryDocument(id, periodLeagueId, userId, userId, 0)) with { Xp = (existing?.Xp ?? 0) + xp };
        await context.Leaderboard.UpsertItemAsync(updated, new PartitionKey(periodLeagueId), cancellationToken: cancellationToken);
    }

    private sealed record LeaderboardEntryDocument(string Id, string PeriodLeagueId, string UserId, string DisplayName, int Xp);
}
