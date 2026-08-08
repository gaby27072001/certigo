using System.Security.Claims;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Certigo.Domain.Gamification;
using Certigo.Domain.Progress;
using Certigo.Domain.Tutor;

namespace Certigo.Application.Abstractions;

/// Raised when an optimistic-concurrency (ETag) precondition fails on a write —
/// i.e. the record was modified by another writer since it was read. Callers
/// re-read and re-apply (see <see cref="OptimisticConcurrency"/>).
public sealed class ConcurrencyConflictException(string message) : Exception(message);

/// Raised by an idempotent create when a record with the same id already exists.
/// Used to turn the legacy "check-then-create" race into an atomic guard so a
/// replayed or concurrent submission can never be applied twice.
public sealed class DuplicateRecordException(string message) : Exception(message);

/// Raised when a structurally valid request violates an application invariant.
/// API hosts map it to HTTP 400 without introducing an Application -> API dependency.
public sealed class RequestValidationException(string message) : Exception(message);

/// Raised when the optional tutor LLM cannot be reached or returns a runtime
/// service error. Callers may deliberately fall back to the grounded tutor
/// explanation, but unexpected coding/configuration bugs should still surface.
public sealed class TutorCompletionUnavailableException(string message, Exception? innerException = null)
    : Exception(message, innerException);

/// Raised when the content catalog is empty (Cosmos DB not seeded or all tracks
/// deleted). Converts to HTTP 503 Service Unavailable so the mobile client can
/// display an actionable state instead of silently rendering an empty list.
public sealed class EmptyCatalogException()
    : Exception("The content catalog is empty — the database has not been seeded yet.");

/// Raised when a requested certification track is not found in the content store.
/// Converts to HTTP 404 so callers surface a clear "not found" state.
public sealed class TrackNotFoundException(string trackId)
    : Exception($"Track '{trackId}' was not found in the catalog.");

public interface IUserContext
{
    string UserId { get; }
    string DisplayName { get; }
}

public interface IClock
{
    DateTimeOffset UtcNow { get; }
}

public interface ITokenValidator
{
    Task<TokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default);
}

public sealed record TokenValidationResult(bool Succeeded, ClaimsPrincipal? Principal, string? UserId);

public interface IUserRepository
{
    Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default);
    Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default);
    Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default);
}

public interface IContentRepository
{
    Task<Track?> GetTrackAsync(string trackId, CancellationToken cancellationToken = default);
    Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default);
    Task<LessonAnswerKey?> GetAnswerKeyAsync(string trackId, string lessonId, CancellationToken cancellationToken = default);

    // All answer keys for a track — powers mock-exam composition, which draws
    // gradable items from across every lesson rather than a single one.
    Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(string trackId, CancellationToken cancellationToken = default);

    // Every certification track, for the course picker. Cross-partition (one
    // doc per track, each in its own /trackId partition), so callers should
    // treat it as a low-frequency catalog read, not a hot path.
    Task<IReadOnlyList<Track>> ListTracksAsync(CancellationToken cancellationToken = default);
}

public interface IProgressRepository
{
    Task<ConceptMastery?> GetMasteryAsync(string userId, string trackId, string conceptId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ConceptMastery>> ListMasteriesAsync(string userId, string trackId, CancellationToken cancellationToken = default);
    Task UpsertMasteryBatchAsync(string userId, IReadOnlyList<ConceptMastery> masteries, CancellationToken cancellationToken = default);
}

public interface IAttemptRepository
{
    Task<AttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default);
    Task CreateAsync(AttemptRecord attempt, CancellationToken cancellationToken = default);

    // Recent-activity aggregate over the attempts container, used to feed the
    // anti-cheat rate-window detectors (XP farming / submission spam) without an
    // external store. Counts every attempt (lesson + exam) submitted since `since`.
    Task<RecentActivity> GetRecentActivityAsync(string userId, DateTimeOffset since, CancellationToken cancellationToken = default);
}

/// Aggregate of a learner's recent attempts (count + XP) over a sliding window.
public sealed record RecentActivity(int Attempts, int Xp);

// Idempotency + history for graded mock exams. Stored in the attempts container
// alongside lesson attempts, disambiguated by the record's "kind" discriminator.
public interface IExamAttemptRepository
{
    Task<ExamAttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default);
    Task<ExamAttemptRecord?> GetByExamIdAsync(string userId, string examId, CancellationToken cancellationToken = default);
    Task CreateAsync(ExamAttemptRecord attempt, CancellationToken cancellationToken = default);
}

/// Server-issued mock exams. Records share the attempts container and are scoped
/// by /userId so an exam id can never be resolved across learner partitions.
public interface IExamRepository
{
    Task CreateAsync(ExamRecord exam, CancellationToken cancellationToken = default);
    Task<ExamRecord?> GetAsync(string userId, string examId, CancellationToken cancellationToken = default);
}

public interface IEventRepository
{
    Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default);
}

// The per-(user, track) behavioural memory that makes the tutor a continuously
// learning agent. Stored in the progress container (PK = /userId) under an
// "learnermodel::{trackId}" id discriminator, so no new container is needed.
public interface ILearnerModelRepository
{
    Task<LearnerModelRecord?> GetAsync(string userId, string trackId, CancellationToken cancellationToken = default);
    Task UpsertAsync(LearnerModelRecord model, CancellationToken cancellationToken = default);
}

// Optional LLM upgrade for the tutor. Returns the model's raw reply (expected to
// be the JSON object described by TutorPromptBuilder), or null when no provider
// is configured — in which case the service serves the grounded explanation. The
// default production binding is a Null implementation, so the tutor works for
// free and offline; any returned text is still guardrail-validated before use.
public interface ITutorCompletion
{
    Task<string?> CompleteAsync(string systemPrompt, string userPrompt, CancellationToken cancellationToken = default);
}

/// Dedicated LLM observability seam so the tutor can report outcomes without
/// taking a dependency on a specific telemetry backend.
public interface ITutorLlmTelemetry
{
    void TrackSuccess(TimeSpan latency);
    void TrackControlledFallback(TimeSpan latency, string reason);
    void TrackUnexpectedError(TimeSpan latency, Exception exception);
    void TrackRejectedResponse(TimeSpan latency, string reason);
}

public sealed class NullTutorLlmTelemetry : ITutorLlmTelemetry
{
    public void TrackSuccess(TimeSpan latency) { }
    public void TrackControlledFallback(TimeSpan latency, string reason) { }
    public void TrackUnexpectedError(TimeSpan latency, Exception exception) { }
    public void TrackRejectedResponse(TimeSpan latency, string reason) { }
}

public interface ILeaderboardRepository
{
    Task<LeagueDto> GetLeagueAsync(string userId, CancellationToken cancellationToken = default);
    Task AddXpAsync(string userId, int xp, CancellationToken cancellationToken = default);
}

public interface IPurchaseRepository
{
    Task<PurchaseRecord?> GetByClientPurchaseIdAsync(string userId, string clientPurchaseId, CancellationToken cancellationToken = default);
    Task CreateAsync(PurchaseRecord record, CancellationToken cancellationToken = default);
}

public interface IFriendRepository
{
    Task<IReadOnlyList<FriendEdge>> ListAsync(string userId, CancellationToken cancellationToken = default);
    Task<FriendEdge?> GetAsync(string userId, string friendUserId, CancellationToken cancellationToken = default);
    Task UpsertAsync(FriendEdge edge, CancellationToken cancellationToken = default);
    Task RemoveAsync(string userId, string friendUserId, CancellationToken cancellationToken = default);
}

// One directed edge of the friend graph; a mutual friendship is two edges so
// each side can list its friends from its own partition (PK = /userId).
public sealed record FriendEdge(
    string Id,
    string UserId,
    string FriendUserId,
    DateTimeOffset CreatedAt);

public sealed record PurchaseRecord(
    string Id,
    string UserId,
    string ClientPurchaseId,
    string ItemId,
    int GemsSpent,
    DateTimeOffset PurchasedAt,
    PurchaseResultDto Result);

public sealed record AttemptRecord(
    string Id,
    string UserId,
    string ClientAttemptId,
    string TrackId,
    string LessonId,
    DateTimeOffset StartedAt,
    DateTimeOffset SubmittedAt,
    SubmitQuizResult Result);

// A graded mock-exam attempt. Shares the attempts container with AttemptRecord;
// the get-only Kind property serialises a "kind":"exam" discriminator so the two
// shapes never cross-contaminate idempotency lookups.
public sealed record ExamAttemptRecord(
    string Id,
    string UserId,
    string ClientAttemptId,
    string TrackId,
    string ExamId,
    DateTimeOffset StartedAt,
    DateTimeOffset SubmittedAt,
    MockExamResultDto Result)
{
    public string Kind => "exam";
}

// The server-side authority for a generated exam. Ttl is serialized as Cosmos'
// per-item "ttl" field; DurationSeconds/ExpiresAt remain explicit for validation.
public sealed record ExamRecord(
    string Id,
    string UserId,
    string ExamId,
    string TrackId,
    IReadOnlyList<string> ItemIds,
    DateTimeOffset CreatedAt,
    int DurationSeconds,
    DateTimeOffset ExpiresAt,
    int Ttl)
{
    public string Kind => "exam-issued";
}

public sealed record LearningEvent(
    string Id,
    string UserId,
    string Type,
    DateTimeOffset OccurredAt,
    object Payload);

// The persisted learner model: every concept the user has touched on a track,
// with the running per-concept stats the tutor personalises on. Carried as a
// single document so a read/observe/upsert cycle is one point-read + one upsert.
public sealed record LearnerModelRecord(
    string UserId,
    string TrackId,
    IReadOnlyList<LearnerConceptStat> Concepts,
    DateTimeOffset UpdatedAt);

public sealed record UserGamification(UserProfileDto Profile, GamificationStats Stats);
