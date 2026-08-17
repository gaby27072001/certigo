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

    // The certification catalog for the course picker: a lightweight summary per
    // track (counts only, no lesson bodies), ordered fundamentals → expert.
    Task<CatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default);
}

public sealed class ContentService(IContentRepository content) : IContentService
{
    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => content.GetLessonAsync(trackId, lessonId, cancellationToken);

    public async Task<CatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default)
    {
        var tracks = await content.ListTracksAsync(cancellationToken);
        if (!tracks.Any())
            throw new EmptyCatalogException();

        var summaries = tracks.Select(ToSummary).ToList();
        summaries.AddRange(
            OfficialCertificationCatalog.MissingReplacementSummaries(tracks.Select(t => t.Code)));

        var ordered = summaries
            .OrderBy(s => LevelRank(s.Level))
            .ThenBy(s => s.Code, StringComparer.Ordinal)
            .ToArray();
        return new CatalogDto(ordered);
    }

    private static TrackSummaryDto ToSummary(Track track)
    {
        var official = OfficialCertificationCatalog.Find(track.Code);
        return new TrackSummaryDto(
            Id: track.Id,
            Code: track.Code,
            Title: OfficialCertificationCatalog.TitleFor(track.Code, track.Title),
            Level: track.Level ?? string.Empty,
            Summary: official?.Summary ?? track.Summary,
            UnitCount: track.Units.Count,
            LessonCount: track.Units.Sum(u => u.Lessons.Count),
            Domains: official?.Domains ?? Array.Empty<CertificationDomainDto>(),
            Prerequisites: official?.Prerequisites ?? string.Empty,
            StudyGuideUrl: official?.StudyGuideUrl ?? string.Empty,
            ExamUrl: official?.ExamUrl ?? string.Empty,
            BlueprintDate: official?.BlueprintDate,
            Lifecycle: official?.Lifecycle ?? string.Empty,
            LifecycleNote: official?.LifecycleNote ?? string.Empty,
            ExamDetailsNote: official?.ExamDetailsNote ?? string.Empty,
            ReplacementCode: official?.ReplacementCode ?? string.Empty,
            MigrationNote: official?.MigrationNote ?? string.Empty);
    }

    // Order the picker the way Microsoft tiers certifications: Fundamentals
    // first, then Associate, then Expert, with anything unlabelled last.
    private static int LevelRank(string level) => level.ToLowerInvariant() switch
    {
        "fundamentals" => 0,
        "associate" => 1,
        "expert" => 2,
        _ => 3,
    };
}
