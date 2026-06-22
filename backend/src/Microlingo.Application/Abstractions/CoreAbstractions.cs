using System.Security.Claims;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Progress;

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
    Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default);
}

public interface IContentRepository
{
    Task<Track?> GetTrackAsync(string trackId, CancellationToken cancellationToken = default);
    Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default);
    Task<LessonAnswerKey?> GetAnswerKeyAsync(string trackId, string lessonId, CancellationToken cancellationToken = default);
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

public interface IEventRepository
{
    Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default);
}

public interface ILeaderboardRepository
{
    Task<LeagueDto> GetLeagueAsync(string userId, CancellationToken cancellationToken = default);
    Task AddXpAsync(string userId, int xp, CancellationToken cancellationToken = default);
}

public sealed record AttemptRecord(
    string Id,
    string UserId,
    string ClientAttemptId,
    string TrackId,
    string LessonId,
    DateTimeOffset StartedAt,
    DateTimeOffset SubmittedAt,
    SubmitQuizResult Result);

public sealed record LearningEvent(
    string Id,
    string UserId,
    string Type,
    DateTimeOffset OccurredAt,
    object Payload);

public sealed record UserGamification(UserProfileDto Profile, GamificationStats Stats);
