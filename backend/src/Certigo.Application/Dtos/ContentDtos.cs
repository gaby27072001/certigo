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
    int LessonCount);

public sealed record CatalogDto(IReadOnlyList<TrackSummaryDto> Tracks);
