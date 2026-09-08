namespace Certigo.Application.Dtos;

public sealed record VivaLearningProviderDto(
    string Id,
    string DisplayName,
    bool IsCourseActivitySyncEnabled);

public sealed record VivaLearningContentFixtureDto(
    string Id,
    string TrackId,
    string LessonId,
    string Title,
    string Description,
    string LanguageTag,
    int EstimatedMinutes,
    string Format,
    string Level,
    string SourceName,
    bool IsActive,
    bool IsPremium,
    bool IsSearchable);

public sealed record VivaLearningContentDto(
    string Id,
    string OrganizationId,
    string ExternalId,
    string TrackId,
    string LessonId,
    string Title,
    string Description,
    string ContentWebUrl,
    string LanguageTag,
    string Duration,
    string Format,
    string Level,
    string SourceName,
    bool IsActive,
    bool IsPremium,
    bool IsSearchable);
