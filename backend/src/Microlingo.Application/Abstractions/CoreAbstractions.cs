using System.Security.Claims;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Tutor;

namespace Microlingo.Application.Abstractions;

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
}

// Idempotency + history for graded mock exams. Stored in the attempts container
// alongside lesson attempts, disambiguated by the record's "kind" discriminator.
public interface IExamAttemptRepository
{
    Task<ExamAttemptRecord?> GetByClientAttemptIdAsync(string userId, string clientAttemptId, CancellationToken cancellationToken = default);
    Task CreateAsync(ExamAttemptRecord attempt, CancellationToken cancellationToken = default);
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
