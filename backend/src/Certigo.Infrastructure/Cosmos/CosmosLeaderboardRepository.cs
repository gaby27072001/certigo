using Microsoft.Azure.Cosmos;
using System.Net;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Gamification;

namespace Certigo.Infrastructure.Cosmos;

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
