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
                .Where(entry => entry.Status is not ("retired" or "replaced"))
                .Select(ToPlannedSummary));

        var ordered = summaries
            .OrderBy(summary => ProviderRank(summary.Provider))
            .ThenBy(summary => LevelRank(summary.CertificationLevel))
            .ThenBy(
                summary => string.IsNullOrEmpty(summary.Code) ? summary.Title : summary.Code,
                StringComparer.Ordinal)
            .ToArray();
        return new CatalogDto(
            Schema: CertificationCatalogSchemas.EmittedAppV2,
            SourceSchema: _certifications.SourceSchema,
            SourceAsOf: _certifications.AsOf,
            Freshness: _certifications.Freshness is null
                ? null
                : new CatalogFreshnessDto(
                    _certifications.Freshness.MaxAgeDays,
                    _certifications.Freshness.ReviewDueOn),
            Providers: _certifications.Providers
                .Select(provider => new CertificationProviderDto(
                    provider.Id,
                    provider.Name,
                    provider.Namespace,
                    provider.OfficialCatalogUrl,
                    provider.SourceHosts,
                    provider.CheckedOn))
                .ToArray(),
            Tracks: ordered);
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
            contentStatus: "planned");

    private TrackSummaryDto ToExternalDto(
        CertificationCatalogEntry entry,
        string summary,
        int unitCount,
        int lessonCount,
        string contentStatus)
        => new(
            Id: entry.Id,
            Code: entry.OfficialCode ?? string.Empty,
            Title: entry.Title,
            Level: entry.Level,
            Summary: summary,
            UnitCount: unitCount,
            LessonCount: lessonCount,
            Domains: Array.Empty<CertificationDomainDto>(),
            Prerequisites: string.Empty,
            StudyGuideUrl: entry.Guide.Url,
            ExamUrl: entry.OfficialUrl,
            BlueprintDate: null,
            Lifecycle: entry.Status,
            LifecycleNote: entry.Lifecycle?.Note ?? string.Empty,
            LearningAvailable: contentStatus == "available",
            Provider: entry.Provider,
            Family: ExternalFamily(entry),
            CertificationLevel: entry.Level,
            Status: entry.Status,
            ContentStatus: contentStatus,
            OfficialUrl: entry.OfficialUrl,
            ExamGuideUrl: entry.Guide.Url,
            CatalogVersion: _certifications.Version,
            BlueprintVersion: entry.Blueprint.Version,
            OfficialCode: entry.OfficialCode,
            Slug: entry.Slug,
            OfficialSlug: entry.OfficialSlug,
            Guide: new CertificationGuideDto(
                entry.Guide.Url,
                entry.Guide.Version,
                entry.Guide.PublishedOn,
                entry.Guide.VersionSource,
                entry.Guide.RevisionToken),
            Blueprint: new CertificationBlueprintDto(
                entry.Blueprint.Version,
                entry.Blueprint.Objectives
                    .Select(objective => new CertificationObjectiveDto(
                        objective.Id,
                        objective.Title,
                        objective.WeightPercent,
                        objective.WeightType))
                    .ToArray()),
            LifecycleDetails: entry.Lifecycle is null
                ? null
                : new CertificationLifecycleDto(
                    entry.Lifecycle.ReviewOn,
                    entry.Lifecycle.LastExamOn,
                    entry.Lifecycle.Replaces,
                    entry.Lifecycle.Successor,
                    entry.Lifecycle.Note),
            Provenance: new CertificationProvenanceDto(
                entry.Provenance.CheckedOn,
                entry.Provenance.Sources
                    .Select(source => new CertificationSourceDto(source.Kind, source.Url))
                    .ToArray()));

    private static string ExternalFamily(CertificationCatalogEntry entry)
    {
        var searchable = $"{entry.OfficialSlug} {entry.Title}".ToLowerInvariant();
        if (searchable.Contains("cloud-digital-leader", StringComparison.Ordinal)
            || searchable.Contains("cloud-practitioner", StringComparison.Ordinal))
            return "cloud-foundations";
        if (searchable.Contains("architect", StringComparison.Ordinal))
            return "architecture";
        if (searchable.Contains("devops", StringComparison.Ordinal))
            return "devops";
        if (searchable.Contains("network", StringComparison.Ordinal))
            return "networking";
        if (searchable.Contains("security operations", StringComparison.Ordinal))
            return "security-operations";
        if (searchable.Contains("security", StringComparison.Ordinal))
            return "security";
        if (searchable.Contains("database", StringComparison.Ordinal))
            return "database";
        if (searchable.Contains("machine learning", StringComparison.Ordinal)
            || searchable.Contains("machine-learning", StringComparison.Ordinal))
            return "machine-learning";
        if (searchable.Contains("generative ai", StringComparison.Ordinal))
            return "generative-ai";
        if (searchable.Contains(" ai ", StringComparison.Ordinal))
            return "ai";
        if (searchable.Contains("data", StringComparison.Ordinal))
            return "data";
        if (searchable.Contains("developer", StringComparison.Ordinal))
            return "development";
        if (searchable.Contains("workspace", StringComparison.Ordinal))
            return "collaboration";
        if (searchable.Contains("operations", StringComparison.Ordinal)
            || searchable.Contains("cloudops", StringComparison.Ordinal)
            || searchable.Contains("sysops", StringComparison.Ordinal))
            return "operations";
        return "other";
    }

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
