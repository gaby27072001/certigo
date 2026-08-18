using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Certigo.Domain.Exam;
using Certigo.Domain.Gamification;
using Certigo.Domain.Integrity;
using Certigo.Domain.Notifications;
using Certigo.Domain.Progress;
using Certigo.Domain.Readiness;
using Certigo.Domain.Recommendation;
using Certigo.Domain.Social;
using Certigo.Domain.Tutor;

namespace Certigo.Application.Services;

public interface IContentService
{
    Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default);

    // Lightweight multi-cloud certification metadata and content availability,
    // without lesson bodies.
    Task<CatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default);
}

public sealed class ContentService : IContentService
{
    private readonly IContentRepository _content;
    private readonly ICertificationRegistry _certifications;

    public ContentService(IContentRepository content)
        : this(content, EmptyCertificationRegistry.Instance)
    {
    }

    public ContentService(IContentRepository content, ICertificationRegistry certifications)
    {
        _content = content;
        _certifications = certifications;
    }

    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => _content.GetLessonAsync(trackId, lessonId, cancellationToken);

    public async Task<CatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default)
    {
        var tracks = await _content.ListTracksAsync(cancellationToken);
        if (!tracks.Any() && _certifications.Entries.Count == 0)
            throw new EmptyCatalogException();

        var registryById = _certifications.Entries.ToDictionary(entry => entry.Id, StringComparer.Ordinal);
        var contentIds = tracks.Select(track => track.Id).ToHashSet(StringComparer.Ordinal);
        var summaries = tracks.Select(track =>
        {
            registryById.TryGetValue(track.Id, out var metadata);
            return ToSummary(track, metadata);
        }).ToList();

        summaries.AddRange(
            OfficialCertificationCatalog.MissingReplacementSummaries(tracks.Select(track => track.Code)));

        var summaryIds = summaries.Select(summary => summary.Id).ToHashSet(StringComparer.Ordinal);
        summaries.AddRange(
            _certifications.Entries
                .Where(entry => !contentIds.Contains(entry.Id) && !summaryIds.Contains(entry.Id))
                .Select(ToPlannedSummary));

        var ordered = summaries
            .OrderBy(summary => ProviderRank(summary.Provider))
            .ThenBy(summary => LevelRank(summary.CertificationLevel))
            .ThenBy(
                summary => string.IsNullOrEmpty(summary.Code) ? summary.Title : summary.Code,
                StringComparer.Ordinal)
            .ToArray();
        return new CatalogDto(ordered);
    }

    private TrackSummaryDto ToSummary(Track track, CertificationCatalogEntry? metadata)
        => metadata is null ? ToAuthoredSummary(track) : ToExternalSummary(track, metadata);

    private static TrackSummaryDto ToAuthoredSummary(Track track)
    {
        var official = OfficialCertificationCatalog.Find(track.Code);
        var legacyLevel = track.Level ?? string.Empty;
        var provider = LegacyProvider(track);
        var status = official?.Lifecycle is "active" or "retired" ? official.Lifecycle : "active";

        return new TrackSummaryDto(
            Id: track.Id,
            Code: track.Code,
            Title: OfficialCertificationCatalog.TitleFor(track.Code, track.Title),
            Level: legacyLevel,
            Summary: official?.Summary ?? track.Summary,
            UnitCount: track.Units.Count,
            LessonCount: track.Units.Sum(unit => unit.Lessons.Count),
            Domains: official?.Domains ?? Array.Empty<CertificationDomainDto>(),
            Prerequisites: official?.Prerequisites ?? string.Empty,
            StudyGuideUrl: official?.StudyGuideUrl ?? string.Empty,
            ExamUrl: official?.ExamUrl ?? string.Empty,
            BlueprintDate: official?.BlueprintDate,
            Lifecycle: official?.Lifecycle ?? string.Empty,
            LifecycleNote: official?.LifecycleNote ?? string.Empty,
            ExamDetailsNote: official?.ExamDetailsNote ?? string.Empty,
            LearningAvailable: true,
            ReplacementCode: official?.ReplacementCode ?? string.Empty,
            MigrationNote: official?.MigrationNote ?? string.Empty,
            Provider: provider,
            Family: LegacyFamily(track, provider),
            CertificationLevel: NormalizeLevel(legacyLevel),
            Status: status,
            ContentStatus: "available",
            OfficialUrl: official?.ExamUrl,
            ExamGuideUrl: official?.StudyGuideUrl,
            BlueprintPublishedOn: official?.BlueprintDate);
    }

    private TrackSummaryDto ToExternalSummary(Track track, CertificationCatalogEntry metadata)
        => ToExternalDto(
            metadata,
            summary: track.Summary,
            unitCount: track.Units.Count,
            lessonCount: track.Units.Sum(unit => unit.Lessons.Count),
            contentStatus: "available");

    private TrackSummaryDto ToPlannedSummary(CertificationCatalogEntry entry)
        => ToExternalDto(
            entry,
            summary: string.Empty,
            unitCount: 0,
            lessonCount: 0,
            contentStatus: entry.ContentStatus);

    private TrackSummaryDto ToExternalDto(
        CertificationCatalogEntry entry,
        string summary,
        int unitCount,
        int lessonCount,
        string contentStatus)
        => new(
            Id: entry.Id,
            Code: entry.Code,
            Title: entry.Title,
            Level: entry.Level,
            Summary: summary,
            UnitCount: unitCount,
            LessonCount: lessonCount,
            Domains: Array.Empty<CertificationDomainDto>(),
            Prerequisites: entry.Prerequisites ?? string.Empty,
            StudyGuideUrl: entry.ExamGuideUrl ?? string.Empty,
            ExamUrl: entry.OfficialUrl,
            BlueprintDate: entry.BlueprintPublishedOn,
            Lifecycle: entry.Status,
            LearningAvailable: contentStatus == "available",
            Provider: entry.Provider,
            Family: entry.Family,
            CertificationLevel: entry.Level,
            Status: entry.Status,
            ContentStatus: contentStatus,
            OfficialUrl: entry.OfficialUrl,
            ExamGuideUrl: entry.ExamGuideUrl,
            CatalogVersion: _certifications.Version,
            BlueprintPublishedOn: entry.BlueprintPublishedOn,
            BlueprintVersion: entry.BlueprintVersion,
            Languages: entry.Languages,
            DurationMinutes: entry.DurationMinutes,
            Aliases: entry.Aliases,
            ReplacedBy: entry.ReplacedBy,
            RetiresOn: entry.RetiresOn,
            RetiredOn: entry.RetiredOn);

    private static string LegacyProvider(Track track)
        => track.Id.StartsWith("github", StringComparison.OrdinalIgnoreCase)
            || track.Id.StartsWith("gh-", StringComparison.OrdinalIgnoreCase)
            || track.Code.StartsWith("GH", StringComparison.OrdinalIgnoreCase)
                ? "github"
                : "microsoft";

    private static string LegacyFamily(Track track, string provider)
    {
        if (provider == "github")
            return "github";

        var prefix = track.Code.Split('-', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
        return prefix?.ToUpperInvariant() switch
        {
            "AZ" => "azure",
            "SC" => "security",
            "AI" or "DP" => "data-ai",
            "MS" or "MD" => "microsoft-365",
            "PL" => "power-platform",
            "MB" => "dynamics-365",
            "MO" => "microsoft-office",
            _ => "other",
        };
    }

    private static int ProviderRank(string provider) => provider switch
    {
        "microsoft" => 0,
        "github" => 1,
        "aws" => 2,
        "gcp" => 3,
        _ => 4,
    };

    private static int LevelRank(string level) => level.ToLowerInvariant() switch
    {
        "foundational" or "fundamentals" => 0,
        "associate" => 1,
        "professional" or "expert" => 2,
        "specialty" => 3,
        _ => 4,
    };

    private static string NormalizeLevel(string level) => level.ToLowerInvariant() switch
    {
        "foundational" or "fundamentals" => "foundational",
        "associate" => "associate",
        "professional" or "expert" => "professional",
        "specialty" => "specialty",
        _ => "unspecified",
    };
}
