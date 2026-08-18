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
    DateOnly? RetiredOn = null);

public sealed record CertificationDomainDto(
    string Id,
    string Name,
    int MinWeightPct,
    int MaxWeightPct);

public sealed record CatalogDto(IReadOnlyList<TrackSummaryDto> Tracks);
