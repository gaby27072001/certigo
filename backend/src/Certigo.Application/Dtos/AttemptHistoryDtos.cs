namespace Certigo.Application.Dtos;

public sealed record AttemptHistorySummaryDto(
    string Kind,
    string AttemptId,
    string ClientAttemptId,
    string TrackId,
    string LessonId,
    DateTimeOffset SubmittedAt,
    int ScorePct,
    int AnsweredCount,
    int CorrectCount,
    int XpEarned,
    int GemsEarned,
    string? PublicManifestId);

public sealed record AttemptHistoryPageDto(
    IReadOnlyList<AttemptHistorySummaryDto> Items,
    string? NextCursor);
