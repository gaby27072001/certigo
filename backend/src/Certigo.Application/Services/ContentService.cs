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
        var summaries = tracks
            .Select(t => new TrackSummaryDto(
                Id: t.Id,
                Code: t.Code,
                Title: t.Title,
                Level: t.Level ?? string.Empty,
                Summary: t.Summary,
                UnitCount: t.Units.Count,
                LessonCount: t.Units.Sum(u => u.Lessons.Count)))
            .OrderBy(s => LevelRank(s.Level))
            .ThenBy(s => s.Code, StringComparer.Ordinal)
            .ToArray();
        return new CatalogDto(summaries);
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
