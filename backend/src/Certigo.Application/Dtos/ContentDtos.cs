namespace Certigo.Application.Dtos;

// --- Path (skill-path) -----------------------------------------------------

public sealed record PathDto(
    string TrackId,
    string TrackName,
    string Exam,
    int ReadinessScore,
    int ReadinessTrend7d,
    IReadOnlyList<PathUnitDto> Units,
    IReadOnlyList<DomainProgressDto> Domains);

public sealed record PathUnitDto(
    string Id,
    string Title,
    string DomainId,
    string Status,
    IReadOnlyList<PathLessonDto> Lessons);

public sealed record PathLessonDto(
    string Id,
    string Title,
    string Status,
    int EstMinutes,
    int MasteryPct);

public sealed record DomainProgressDto(
    string Id,
    string Name,
    double Weight,
    int Score);

// --- Catalog (certification picker) ---------------------------------------

public sealed record TrackSummaryDto(
    string Id,
    string Code,
    string Title,
    string Level,
    string Summary,
    int UnitCount,
    int LessonCount,
    IReadOnlyList<CertificationDomainDto>? Domains = null,
    string Prerequisites = "",
    string StudyGuideUrl = "",
    string ExamUrl = "",
    DateOnly? BlueprintDate = null,
    string Lifecycle = "",
    string LifecycleNote = "",
    string ExamDetailsNote = "",
    bool LearningAvailable = true,
    string ReplacementCode = "",
    string MigrationNote = "",
    string Provider = "microsoft",
    string Family = "other",
    string CertificationLevel = "unspecified",
    string Status = "active",
    string ContentStatus = "available",
    string? OfficialUrl = null,
    string? ExamGuideUrl = null,
    string? CatalogVersion = null,
    DateOnly? BlueprintPublishedOn = null,
    string? BlueprintVersion = null,
    IReadOnlyList<string>? Languages = null,
    int? DurationMinutes = null,
    IReadOnlyList<string>? Aliases = null,
    string? ReplacedBy = null,
    DateOnly? RetiresOn = null,
    DateOnly? RetiredOn = null,
    string? OfficialCode = null,
    string? Slug = null,
    string? OfficialSlug = null,
    CertificationGuideDto? Guide = null,
    CertificationBlueprintDto? Blueprint = null,
    CertificationLifecycleDto? LifecycleDetails = null,
    CertificationProvenanceDto? Provenance = null);

public sealed record CertificationDomainDto(
    string Id,
    string Name,
    int MinWeightPct,
    int MaxWeightPct);

public sealed record CertificationGuideDto(
    string Url,
    string? Version,
    DateOnly? PublishedOn,
    string? VersionSource,
    string? RevisionToken);

public sealed record CertificationBlueprintDto(
    string Version,
    IReadOnlyList<CertificationObjectiveDto> Objectives);

public sealed record CertificationObjectiveDto(
    string Id,
    string Title,
    decimal WeightPercent,
    string WeightType);

public sealed record CertificationLifecycleDto(
    DateOnly? ReviewOn = null,
    DateOnly? LastExamOn = null,
    IReadOnlyList<string>? Replaces = null,
    string? Successor = null,
    string? Note = null);

public sealed record CertificationProvenanceDto(
    DateOnly CheckedOn,
    IReadOnlyList<CertificationSourceDto> Sources);

public sealed record CertificationSourceDto(
    string Kind,
    string Url);

public sealed record CertificationProviderDto(
    string Id,
    string Name,
    string Namespace,
    string? OfficialCatalogUrl,
    IReadOnlyList<string> SourceHosts,
    DateOnly? CheckedOn);

public sealed record CatalogFreshnessDto(
    int MaxAgeDays,
    DateOnly ReviewDueOn);

public sealed record CatalogDto(
    string Schema,
    string SourceSchema,
    DateOnly? SourceAsOf,
    CatalogFreshnessDto? Freshness,
    IReadOnlyList<CertificationProviderDto> Providers,
    IReadOnlyList<TrackSummaryDto> Tracks);
