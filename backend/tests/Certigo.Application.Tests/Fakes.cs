using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Certigo.Domain.Progress;

namespace Certigo.Application.Tests;

internal sealed class FakeClock(DateTimeOffset now) : IClock
{
    public DateTimeOffset UtcNow { get; set; } = now;
}

internal sealed class FakeUserContext(string userId, string displayName) : IUserContext
{
    public string UserId { get; } = userId;
    public string DisplayName { get; } = displayName;
}

internal sealed class SpyTutorLlmTelemetry : ITutorLlmTelemetry
{
    public List<double> SuccessCalls { get; } = new();
    public List<(double LatencyMs, string Reason)> ControlledFallbacks { get; } = new();
    public List<(double LatencyMs, string ExceptionType)> UnexpectedErrors { get; } = new();
    public List<(double LatencyMs, string Reason)> RejectedResponses { get; } = new();

    public void TrackSuccess(TimeSpan latency) => SuccessCalls.Add(latency.TotalMilliseconds);

    public void TrackControlledFallback(TimeSpan latency, string reason)
        => ControlledFallbacks.Add((latency.TotalMilliseconds, reason));

    public void TrackUnexpectedError(TimeSpan latency, Exception exception)
        => UnexpectedErrors.Add((latency.TotalMilliseconds, exception.GetType().Name));

    public void TrackRejectedResponse(TimeSpan latency, string reason)
        => RejectedResponses.Add((latency.TotalMilliseconds, reason));
}

internal sealed class InMemoryUserRepository : IUserRepository
{
    private readonly Dictionary<string, UserProfileDto> _store = new(StringComparer.OrdinalIgnoreCase);
    private long _version;

    public UserProfileDto? Seed(UserProfileDto profile)
    {
        var stored = profile with { ETag = NextETag() };
        _store[stored.Id] = stored;
        return stored;
    }

    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(userId));

    public Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.Values.FirstOrDefault(p => string.Equals(p.Handle, handle, StringComparison.OrdinalIgnoreCase)));

    public Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default)
    {
        // Model Cosmos optimistic concurrency: a write carrying a stale ETag loses.
        if (_store.TryGetValue(profile.Id, out var current)
            && (string.IsNullOrEmpty(profile.ETag)
                || !string.Equals(profile.ETag, current.ETag, StringComparison.Ordinal)))
        {
            throw new ConcurrencyConflictException($"User profile '{profile.Id}' was modified concurrently.");
        }

        var stored = profile with { ETag = NextETag() };
        _store[stored.Id] = stored;
        return Task.FromResult(stored);
    }

    /// Test seam: simulate a competing writer mutating the profile out-of-band,
    /// which bumps the stored ETag and makes the next stale-ETag upsert conflict.
    public void ForceConcurrentWrite(string userId, Func<UserProfileDto, UserProfileDto> mutate)
    {
        var current = _store[userId];
        _store[userId] = mutate(current) with { ETag = NextETag() };
    }

    private string NextETag() => $"\"{System.Threading.Interlocked.Increment(ref _version)}\"";
}

/// Wraps the in-memory user repo to simulate a DISTINCT concurrent writer: on the
/// first upsert it commits an out-of-band profile mutation (bumping the stored ETag)
/// AND throws a conflict, forcing the caller to re-read the fresher profile and
/// re-apply its own delta on top. Proves the absence of lost update — the competing
/// writer's change and ours must both survive. Subsequent writes delegate.
internal sealed class BumpThenConflictUserRepository(
    InMemoryUserRepository inner,
    Func<UserProfileDto, UserProfileDto> concurrentMutation) : IUserRepository
{
    private bool _bumped;

    public int UpsertCalls { get; private set; }

    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
        => inner.GetAsync(userId, cancellationToken);

    public Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default)
        => inner.FindByHandleAsync(handle, cancellationToken);

    public Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default)
    {
        UpsertCalls++;
        if (!_bumped)
        {
            _bumped = true;
            inner.ForceConcurrentWrite(profile.Id, concurrentMutation);
            throw new ConcurrencyConflictException("simulated distinct concurrent write");
        }

        return inner.UpsertAsync(profile, cancellationToken);
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

    public Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(string trackId, CancellationToken cancellationToken = default)
    {
        IReadOnlyList<LessonAnswerKey> result = _answerKeys.Values
            .Where(k => string.Equals(k.TrackId, trackId, StringComparison.OrdinalIgnoreCase))
            .ToArray();
        return Task.FromResult(result);
    }

    public Task<IReadOnlyList<Track>> ListTracksAsync(CancellationToken cancellationToken = default)
    {
        IReadOnlyList<Track> result = _tracks.Values.ToArray();
        return Task.FromResult(result);
    }
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
            var key = Key(userId, mastery.TrackId, mastery.ConceptId);
            var existing = _store.GetValueOrDefault(key);
            if (existing is null
                || mastery.LastReviewedAt > existing.LastReviewedAt
                || mastery.LastReviewedAt == existing.LastReviewedAt && mastery.Reps > existing.Reps)
            {
                _store[key] = mastery;
            }
        }

        return Task.CompletedTask;
    }
}

internal sealed class InMemoryAttemptRepository : IAttemptRepository
{
    private readonly List<AttemptRecord> _store = new();

    public int GetByClientAttemptIdCount { get; private set; }

    public void Seed(AttemptRecord attempt) => _store.Add(attempt);

    public Task<AttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default)
    {
        GetByClientAttemptIdCount++;
        return Task.FromResult(
            _store.FirstOrDefault(a => a.UserId == userId && a.ClientAttemptId == clientAttemptId));
    }

    public Task CreateAsync(AttemptRecord attempt, CancellationToken cancellationToken = default)
    {
        if (_store.Any(a => string.Equals(a.Id, attempt.Id, StringComparison.Ordinal)
            && string.Equals(a.UserId, attempt.UserId, StringComparison.Ordinal)))
        {
            throw new DuplicateRecordException($"Attempt '{attempt.Id}' already exists.");
        }

        _store.Add(attempt);
        return Task.CompletedTask;
    }

    public Task<RecentActivity> GetRecentActivityAsync(string userId, DateTimeOffset since, CancellationToken cancellationToken = default)
    {
        var recent = _store.Where(a => a.UserId == userId && a.SubmittedAt >= since).ToList();
        return Task.FromResult(new RecentActivity(recent.Count, recent.Sum(a => a.Result.Rewards.XpEarned)));
    }
}

internal sealed class InMemoryExamAttemptRepository : IExamAttemptRepository
{
    private readonly List<ExamAttemptRecord> _store = new();

    public int CreateCount { get; private set; }

    public Task<ExamAttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.FirstOrDefault(a => a.UserId == userId && a.ClientAttemptId == clientAttemptId));

    public Task<ExamAttemptRecord?> GetByExamIdAsync(
        string userId,
        string examId,
        CancellationToken cancellationToken = default)
        => Task.FromResult(_store.FirstOrDefault(a => a.UserId == userId && a.ExamId == examId));

    public Task CreateAsync(ExamAttemptRecord attempt, CancellationToken cancellationToken = default)
    {
        if (_store.Any(a => string.Equals(a.Id, attempt.Id, StringComparison.Ordinal)))
        {
            throw new DuplicateRecordException($"Exam attempt '{attempt.Id}' already exists.");
        }

        _store.Add(attempt);
        CreateCount++;
        return Task.CompletedTask;
    }
}

internal sealed class InMemoryExamRepository : IExamRepository
{
    private readonly Dictionary<string, ExamRecord> _store = new(StringComparer.OrdinalIgnoreCase);

    public IReadOnlyCollection<ExamRecord> Records => _store.Values;

    private static string Key(string userId, string examId) => $"{userId}|{examId}";

    public void Seed(ExamRecord exam) => _store[Key(exam.UserId, exam.ExamId)] = exam;

    public Task CreateAsync(ExamRecord exam, CancellationToken cancellationToken = default)
    {
        var key = Key(exam.UserId, exam.ExamId);
        if (_store.ContainsKey(key))
        {
            throw new DuplicateRecordException($"Exam '{exam.Id}' already exists.");
        }

        _store[key] = exam;
        return Task.CompletedTask;
    }

    public Task<ExamRecord?> GetAsync(
        string userId,
        string examId,
        CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(Key(userId, examId)));
}

internal sealed class InMemoryEventRepository : IEventRepository
{
    public List<LearningEvent> Events { get; } = new();

    public Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default)
    {
        if (Events.All(existing => !string.Equals(existing.Id, learningEvent.Id, StringComparison.Ordinal)
            || !string.Equals(existing.UserId, learningEvent.UserId, StringComparison.Ordinal)))
        {
            Events.Add(learningEvent);
        }

        return Task.CompletedTask;
    }
}

internal sealed class FailOnceEventRepository(InMemoryEventRepository inner) : IEventRepository
{
    private bool _failed;

    public Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default)
    {
        if (!_failed)
        {
            _failed = true;
            throw new InvalidOperationException("simulated event projection failure");
        }

        return inner.AddAsync(learningEvent, cancellationToken);
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

    private readonly HashSet<string> _appliedOperations = new(StringComparer.Ordinal);

    public Task AddXpAsync(
        string userId,
        int xp,
        string operationId,
        DateTimeOffset occurredAt,
        CancellationToken cancellationToken = default)
    {
        if (!_appliedOperations.Add(operationId))
        {
            return Task.CompletedTask;
        }

        Xp[userId] = Xp.GetValueOrDefault(userId) + xp;
        return Task.CompletedTask;
    }
}

internal sealed class FailOnceLeaderboardRepository(InMemoryLeaderboardRepository inner) : ILeaderboardRepository
{
    private bool _failed;

    public Task<LeagueDto> GetLeagueAsync(string userId, CancellationToken cancellationToken = default) =>
        inner.GetLeagueAsync(userId, cancellationToken);

    public Task AddXpAsync(
        string userId,
        int xp,
        string operationId,
        DateTimeOffset occurredAt,
        CancellationToken cancellationToken = default)
    {
        if (!_failed)
        {
            _failed = true;
            throw new InvalidOperationException("simulated leaderboard projection failure");
        }

        return inner.AddXpAsync(userId, xp, operationId, occurredAt, cancellationToken);
    }
}

internal sealed class InMemoryEconomyOperationRepository : IEconomyOperationRepository
{
    private readonly Dictionary<string, EconomyOperationRecord> _store = new(StringComparer.Ordinal);
    private readonly object _gate = new();
    private long _version;

    public int GetCount { get; private set; }

    public Task<EconomyOperationRecord?> GetAsync(
        string userId,
        string operationId,
        CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            GetCount++;
            return Task.FromResult(_store.GetValueOrDefault(Key(userId, operationId)));
        }
    }

    public Task<EconomyOperationRecord> GetOrCreateAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            var key = Key(operation.UserId, operation.Id);
            if (_store.TryGetValue(key, out var existing))
            {
                return Task.FromResult(existing);
            }

            var stored = operation with { ETag = NextETag() };
            _store.Add(key, stored);
            return Task.FromResult(stored);
        }
    }

    public Task<EconomyOperationRecord> MarkStepCompletedAsync(
        string userId,
        string operationId,
        string step,
        CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            var key = Key(userId, operationId);
            var current = _store[key];
            if (current.Status == EconomyOperationRecord.FailedStatus)
            {
                throw new ConcurrencyConflictException("failed operation cannot complete a step");
            }

            if (current.HasCompleted(step))
            {
                return Task.FromResult(current);
            }

            var completedSteps = current.CompletedSteps.Append(step).ToArray();
            var status = current.RequiredSteps.All(
                required => completedSteps.Contains(required, StringComparer.Ordinal))
                ? EconomyOperationRecord.CompletedStatus
                : EconomyOperationRecord.PendingStatus;
            var updated = current with
            {
                CompletedSteps = completedSteps,
                Status = status,
                UpdatedAt = DateTimeOffset.UtcNow,
                ETag = NextETag(),
            };
            _store[key] = updated;
            return Task.FromResult(updated);
        }
    }

    public Task<EconomyOperationRecord> MarkFailedAsync(
        string userId,
        string operationId,
        string failureCode,
        CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            var key = Key(userId, operationId);
            var current = _store[key];
            if (current.Status == EconomyOperationRecord.FailedStatus)
            {
                return Task.FromResult(current);
            }

            if (current.Status == EconomyOperationRecord.CompletedStatus
                || current.OutcomeJson is not null)
            {
                throw new ConcurrencyConflictException(
                    "operation already committed a successful outcome");
            }

            var failed = current with
            {
                Status = EconomyOperationRecord.FailedStatus,
                FailureCode = failureCode,
                UpdatedAt = DateTimeOffset.UtcNow,
                ETag = NextETag(),
            };
            _store[key] = failed;
            return Task.FromResult(failed);
        }
    }

    public Task<EconomyOperationRecord> SetOutcomeAsync(
        string userId,
        string operationId,
        string outcomeJson,
        CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            var key = Key(userId, operationId);
            var current = _store[key];
            if (current.Status == EconomyOperationRecord.FailedStatus)
            {
                throw new ConcurrencyConflictException(
                    "failed operation cannot commit an outcome");
            }

            if (current.OutcomeJson is not null)
            {
                if (!string.Equals(current.OutcomeJson, outcomeJson, StringComparison.Ordinal))
                {
                    throw new ConcurrencyConflictException("different durable outcome");
                }

                return Task.FromResult(current);
            }

            var updated = current with
            {
                OutcomeJson = outcomeJson,
                UpdatedAt = DateTimeOffset.UtcNow,
                ETag = NextETag(),
            };
            _store[key] = updated;
            return Task.FromResult(updated);
        }
    }

    private static string Key(string userId, string operationId) => $"{userId}|{operationId}";

    public void Seed(EconomyOperationRecord operation)
    {
        lock (_gate)
        {
            _store[Key(operation.UserId, operation.Id)] = operation with { ETag = NextETag() };
        }
    }
    private string NextETag() => $"\"{Interlocked.Increment(ref _version)}\"";
}

internal sealed class MutateOnceOnEconomyCreateRepository(
    InMemoryEconomyOperationRepository inner,
    Action mutation) : IEconomyOperationRepository
{
    private bool _mutated;

    public Task<EconomyOperationRecord?> GetAsync(
        string userId,
        string operationId,
        CancellationToken cancellationToken = default) =>
        inner.GetAsync(userId, operationId, cancellationToken);

    public async Task<EconomyOperationRecord> GetOrCreateAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken = default)
    {
        var result = await inner.GetOrCreateAsync(operation, cancellationToken);
        if (!_mutated)
        {
            _mutated = true;
            mutation();
        }

        return result;
    }

    public Task<EconomyOperationRecord> MarkStepCompletedAsync(
        string userId,
        string operationId,
        string step,
        CancellationToken cancellationToken = default) =>
        inner.MarkStepCompletedAsync(userId, operationId, step, cancellationToken);

    public Task<EconomyOperationRecord> MarkFailedAsync(
        string userId,
        string operationId,
        string failureCode,
        CancellationToken cancellationToken = default) =>
        inner.MarkFailedAsync(userId, operationId, failureCode, cancellationToken);

    public Task<EconomyOperationRecord> SetOutcomeAsync(
        string userId,
        string operationId,
        string outcomeJson,
        CancellationToken cancellationToken = default) =>
        inner.SetOutcomeAsync(userId, operationId, outcomeJson, cancellationToken);
}

internal sealed class InMemoryPurchaseRepository : IPurchaseRepository
{
    private readonly List<PurchaseRecord> _store = new();

    public int CreateCount { get; private set; }

    public Task<PurchaseRecord?> GetByClientPurchaseIdAsync(string userId, string clientPurchaseId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.FirstOrDefault(p => p.UserId == userId && p.ClientPurchaseId == clientPurchaseId));

    public Task CreateAsync(PurchaseRecord record, CancellationToken cancellationToken = default)
    {
        if (_store.Any(p => string.Equals(p.Id, record.Id, StringComparison.Ordinal)))
        {
            throw new DuplicateRecordException($"Purchase '{record.Id}' already exists.");
        }

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

internal sealed class InMemoryLearnerModelRepository : ILearnerModelRepository
{
    private readonly Dictionary<string, LearnerModelRecord> _store = new(StringComparer.OrdinalIgnoreCase);

    public int UpsertCount { get; private set; }

    private static string Key(string userId, string trackId) => $"{userId}|{trackId}";

    public Task<LearnerModelRecord?> GetAsync(string userId, string trackId, CancellationToken cancellationToken = default)
        => Task.FromResult(_store.GetValueOrDefault(Key(userId, trackId)));

    public Task UpsertAsync(LearnerModelRecord model, CancellationToken cancellationToken = default)
    {
        var key = Key(model.UserId, model.TrackId);
        var current = _store.GetValueOrDefault(key);
        var currentAttempts = current?.Concepts.Sum(concept => concept.Attempts) ?? -1;
        var incomingAttempts = model.Concepts.Sum(concept => concept.Attempts);
        if (current is not null
            && (current.UpdatedAt > model.UpdatedAt
                || current.UpdatedAt == model.UpdatedAt && currentAttempts >= incomingAttempts))
        {
            return Task.CompletedTask;
        }

        _store[key] = model;
        UpsertCount++;
        return Task.CompletedTask;
    }
}

internal sealed class FakeTutorCompletion : ITutorCompletion
{
    private readonly string? _reply;

    public FakeTutorCompletion(string? reply = null) => _reply = reply;

    public int CallCount { get; private set; }
    public string? LastSystemPrompt { get; private set; }
    public string? LastUserPrompt { get; private set; }

    public Task<string?> CompleteAsync(string systemPrompt, string userPrompt, CancellationToken cancellationToken = default)
    {
        CallCount++;
        LastSystemPrompt = systemPrompt;
        LastUserPrompt = userPrompt;
        return Task.FromResult(_reply);
    }
}

internal sealed class ThrowingTutorCompletion(Exception exception) : ITutorCompletion
{
    public Task<string?> CompleteAsync(string systemPrompt, string userPrompt, CancellationToken cancellationToken = default)
        => Task.FromException<string?>(exception);
}

/// <summary>
/// Service de classement contrôlable pour les tests de notifications : on règle la
/// zone (« promotion » / « relegation » / « safe »), le rang et le nombre d'inscrits
/// afin d'exercer le câblage entre la ligue et le plan de notifications. La résolution
/// de fin de ligue n'est jamais sollicitée par la planification, d'où l'exception.
/// </summary>
internal sealed class StubLeaderboardService : ILeaderboardService
{
    public string MyZone { get; set; } = "safe";
    public int MyRank { get; set; }
    public int EntryCount { get; set; }

    public Task<LeagueDto> GetMyLeagueAsync(CancellationToken cancellationToken = default)
    {
        var entries = new List<LeaderboardEntryDto>(EntryCount);
        for (var i = 0; i < EntryCount; i++)
        {
            entries.Add(new LeaderboardEntryDto(
                UserId: $"u{i}",
                DisplayName: $"Apprenant {i}",
                AvatarUrl: null,
                Rank: i + 1,
                WeeklyXp: (EntryCount - i) * 10));
        }

        var league = new LeagueDto(
            PeriodLeagueId: "weekly:test:bronze",
            Tier: "bronze",
            EndsAt: new DateTimeOffset(2026, 6, 29, 0, 0, 0, TimeSpan.Zero),
            PromoteCount: 10,
            MeUserId: "u1",
            Entries: entries)
        {
            MyRank = MyRank,
            MyZone = MyZone,
        };

        return Task.FromResult(league);
    }

    public Task<LeagueResolutionDto> PreviewResolutionAsync(CancellationToken cancellationToken = default)
        => throw new NotSupportedException(
            "La résolution de ligue n'est pas requise pour la planification des notifications.");
}
