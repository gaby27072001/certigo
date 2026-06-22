using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Progress;

namespace Microlingo.Application.Tests;

internal sealed class FakeClock(DateTimeOffset now) : IClock
{
    public DateTimeOffset UtcNow { get; set; } = now;
}

internal sealed class FakeUserContext(string userId, string displayName) : IUserContext
{
    public string UserId { get; } = userId;
    public string DisplayName { get; } = displayName;
}

internal sealed class InMemoryUserRepository : IUserRepository
{
    private readonly Dictionary<string, UserProfileDto> _store = new(StringComparer.OrdinalIgnoreCase);

    public UserProfileDto? Seed(UserProfileDto profile)
    {
        _store[profile.Id] = profile;
        return profile;
    }

    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(userId));

    public Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.Values.FirstOrDefault(p => string.Equals(p.Handle, handle, StringComparison.OrdinalIgnoreCase)));

    public Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default)
    {
        _store[profile.Id] = profile;
        return Task.FromResult(profile);
    }
}

internal sealed class InMemoryContentRepository : IContentRepository
{
    private readonly Dictionary<string, Track> _tracks = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, Lesson> _lessons = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, LessonAnswerKey> _answerKeys = new(StringComparer.OrdinalIgnoreCase);

    public void AddTrack(Track track) => _tracks[track.Id] = track;
    public void AddLesson(Lesson lesson) => _lessons[lesson.Id] = lesson;
    public void AddAnswerKey(LessonAnswerKey key) => _answerKeys[key.LessonId] = key;

    public Task<Track?> GetTrackAsync(string trackId, CancellationToken cancellationToken = default)
        => Task.FromResult(_tracks.GetValueOrDefault(trackId));

    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => Task.FromResult(_lessons.GetValueOrDefault(lessonId));

    public Task<LessonAnswerKey?> GetAnswerKeyAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => Task.FromResult(_answerKeys.GetValueOrDefault(lessonId));
}

internal sealed class InMemoryProgressRepository : IProgressRepository
{
    private readonly Dictionary<string, ConceptMastery> _store = new(StringComparer.OrdinalIgnoreCase);

    private static string Key(string userId, string trackId, string conceptId) => $"{userId}|{trackId}|{conceptId}";

    public void Seed(string userId, ConceptMastery mastery) => _store[Key(userId, mastery.TrackId, mastery.ConceptId)] = mastery;

    public Task<ConceptMastery?> GetMasteryAsync(string userId, string trackId, string conceptId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(Key(userId, trackId, conceptId)));

    public Task<IReadOnlyList<ConceptMastery>> ListMasteriesAsync(string userId, string trackId, CancellationToken cancellationToken = default)
    {
        var prefix = $"{userId}|{trackId}|";
        IReadOnlyList<ConceptMastery> result = _store
            .Where(kv => kv.Key.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            .Select(kv => kv.Value)
            .ToArray();
        return Task.FromResult(result);
    }

    public Task UpsertMasteryBatchAsync(string userId, IReadOnlyList<ConceptMastery> masteries, CancellationToken cancellationToken = default)
    {
        foreach (var mastery in masteries)
        {
            _store[Key(userId, mastery.TrackId, mastery.ConceptId)] = mastery;
        }

        return Task.CompletedTask;
    }
}

internal sealed class InMemoryAttemptRepository : IAttemptRepository
{
    private readonly List<AttemptRecord> _store = new();

    public Task<AttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.FirstOrDefault(a => a.UserId == userId && a.ClientAttemptId == clientAttemptId));

    public Task CreateAsync(AttemptRecord attempt, CancellationToken cancellationToken = default)
    {
        _store.Add(attempt);
        return Task.CompletedTask;
    }
}

internal sealed class InMemoryEventRepository : IEventRepository
{
    public List<LearningEvent> Events { get; } = new();

    public Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default)
    {
        Events.Add(learningEvent);
        return Task.CompletedTask;
    }
}

internal sealed class InMemoryLeaderboardRepository : ILeaderboardRepository
{
    public Dictionary<string, int> Xp { get; } = new(StringComparer.OrdinalIgnoreCase);

    public Task<LeagueDto> GetLeagueAsync(string userId, CancellationToken cancellationToken = default)
    {
        var entries = Xp
            .OrderByDescending(kv => kv.Value)
            .Select((kv, i) => new LeaderboardEntryDto(kv.Key, kv.Key, null, i + 1, kv.Value))
            .ToArray();
        return Task.FromResult(new LeagueDto("weekly:test:bronze", "bronze", DateTimeOffset.UtcNow.AddDays(7), 10, userId, entries));
    }

    public Task AddXpAsync(string userId, int xp, CancellationToken cancellationToken = default)
    {
        Xp[userId] = Xp.GetValueOrDefault(userId) + xp;
        return Task.CompletedTask;
    }
}

internal sealed class InMemoryPurchaseRepository : IPurchaseRepository
{
    private readonly List<PurchaseRecord> _store = new();

    public int CreateCount { get; private set; }

    public Task<PurchaseRecord?> GetByClientPurchaseIdAsync(string userId, string clientPurchaseId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.FirstOrDefault(p => p.UserId == userId && p.ClientPurchaseId == clientPurchaseId));

    public Task CreateAsync(PurchaseRecord record, CancellationToken cancellationToken = default)
    {
        _store.Add(record);
        CreateCount++;
        return Task.CompletedTask;
    }
}

internal sealed class InMemoryFriendRepository : IFriendRepository
{
    private readonly Dictionary<string, FriendEdge> _store = new(StringComparer.OrdinalIgnoreCase);

    private static string Key(string userId, string friendUserId) => $"{userId}:{friendUserId}";

    public Task<IReadOnlyList<FriendEdge>> ListAsync(string userId, CancellationToken cancellationToken = default)
    {
        IReadOnlyList<FriendEdge> result = _store.Values
            .Where(e => string.Equals(e.UserId, userId, StringComparison.OrdinalIgnoreCase))
            .ToArray();
        return Task.FromResult(result);
    }

    public Task<FriendEdge?> GetAsync(string userId, string friendUserId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(Key(userId, friendUserId)));

    public Task UpsertAsync(FriendEdge edge, CancellationToken cancellationToken = default)
    {
        _store[Key(edge.UserId, edge.FriendUserId)] = edge;
        return Task.CompletedTask;
    }

    public Task RemoveAsync(string userId, string friendUserId, CancellationToken cancellationToken = default)
    {
        _store.Remove(Key(userId, friendUserId));
        return Task.CompletedTask;
    }
}
