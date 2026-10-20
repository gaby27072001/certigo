namespace Certigo.Application.Dtos;

public sealed record PilotLessonProgressDto(
    string LessonId,
    DateTimeOffset LastAccessedAt,
    DateTimeOffset? MarkedReadAt);

public sealed record PilotHistoryDto(
    string PilotId,
    string ContentDigest,
    string? LastLessonId,
    IReadOnlyList<PilotLessonProgressDto> Lessons);
