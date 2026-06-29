using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Certigo.Domain.Progress;
using Certigo.Domain.Readiness;

namespace Certigo.Application.Services;

public interface IPathService
{
    Task<PathDto> GetPathAsync(string trackId, CancellationToken cancellationToken = default);
}

public sealed class PathService(
    IUserContext userContext,
    IContentRepository content,
    IProgressRepository progress,
    IClock clock) : IPathService
{
    public async Task<PathDto> GetPathAsync(string trackId, CancellationToken cancellationToken = default)
    {
        var track = await content.GetTrackAsync(trackId, cancellationToken);
        if (track is null)
        {
            return new PathDto(trackId, trackId, trackId, 0, 0, Array.Empty<PathUnitDto>(), Array.Empty<DomainProgressDto>());
        }

        var masteries = await progress.ListMasteriesAsync(userContext.UserId, trackId, cancellationToken);
        var masteryByConcept = masteries
            .GroupBy(m => m.ConceptId, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

        var lessonIds = track.Units.SelectMany(u => u.Lessons).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        var lessons = await Task.WhenAll(lessonIds.Select(id => content.GetLessonAsync(trackId, id, cancellationToken)));
        var lessonById = lessons
            .Where(l => l is not null)
            .Select(l => l!)
            .ToDictionary(l => l.Id, StringComparer.OrdinalIgnoreCase);

        var conceptDomains = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var lesson in lessonById.Values)
        {
            foreach (var conceptId in GradableConcepts(lesson))
            {
                conceptDomains[conceptId] = lesson.DomainId;
            }
        }

        var conceptCountsByDomain = conceptDomains
            .GroupBy(kv => kv.Value)
            .ToDictionary(g => g.Key, g => g.Count());
        var domainWeights = track.Domains.ToDictionary(d => d.Id, d => d.Weight);
        var domainNames = track.Domains.ToDictionary(d => d.Id, d => d.Name);

        var readiness = ReadinessCalculator.Compute(
            trackId,
            domainWeights,
            conceptCountsByDomain,
            masteries,
            clock.UtcNow,
            trend7d: 0,
            conceptDomains: conceptDomains);

        var domainProgress = track.Domains
            .Select(d =>
            {
                var score = readiness.Domains.FirstOrDefault(rd => rd.DomainId == d.Id)?.Score ?? 0;
                return new DomainProgressDto(d.Id, d.Name, d.Weight, score);
            })
            .ToArray();

        var units = new List<PathUnitDto>(track.Units.Count);
        var previousUnitCompleted = true;
        foreach (var unit in track.Units)
        {
            var unitUnlocked = previousUnitCompleted;
            var frontierConsumed = false;
            var pathLessons = new List<PathLessonDto>(unit.Lessons.Count);
            var allLessonsDone = true;

            foreach (var lessonId in unit.Lessons)
            {
                lessonById.TryGetValue(lessonId, out var lesson);
                var concepts = lesson is null ? Array.Empty<string>() : GradableConcepts(lesson).ToArray();
                var total = concepts.Length;
                var tracked = concepts.Count(masteryByConcept.ContainsKey);
                var avg = total == 0
                    ? 0d
                    : concepts.Average(c => masteryByConcept.TryGetValue(c, out var m) ? m.MasteryScore : 0d);
                var masteryPct = (int)Math.Round(avg * 100);

                var rawDone = total > 0 && tracked == total;
                var rawMastered = rawDone && avg >= 0.85;
                var rawInProgress = !rawDone && tracked > 0;

                string status;
                if (!unitUnlocked)
                {
                    status = "locked";
                }
                else if (rawMastered)
                {
                    status = "mastered";
                }
                else if (rawDone)
                {
                    status = "completed";
                }
                else if (!frontierConsumed)
                {
                    status = rawInProgress ? "inProgress" : "available";
                    frontierConsumed = true;
                }
                else
                {
                    status = "locked";
                }

                if (!rawDone)
                {
                    allLessonsDone = false;
                }

                pathLessons.Add(new PathLessonDto(
                    lessonId,
                    lesson?.Title ?? lessonId,
                    status,
                    lesson?.EstMinutes ?? 0,
                    masteryPct));
            }

            units.Add(new PathUnitDto(unit.Id, unit.Title, unit.DomainId, UnitStatus(pathLessons, unitUnlocked), pathLessons));
            previousUnitCompleted = unitUnlocked && allLessonsDone && unit.Lessons.Count > 0;
        }

        return new PathDto(
            track.Id,
            track.Title,
            track.Code,
            readiness.Score,
            0,
            units,
            domainProgress);
    }

    private static IEnumerable<string> GradableConcepts(Lesson lesson)
        => lesson.Blocks
            .Where(b => b.Check is not null)
            .Select(b => b.Check!.ConceptId)
            .Distinct(StringComparer.OrdinalIgnoreCase);

    private static string UnitStatus(IReadOnlyList<PathLessonDto> lessons, bool unlocked)
    {
        if (!unlocked)
        {
            return "locked";
        }

        if (lessons.Count > 0 && lessons.All(l => l.Status is "completed" or "mastered"))
        {
            return lessons.All(l => l.Status == "mastered") ? "mastered" : "completed";
        }

        return lessons.Any(l => l.Status is "inProgress" or "completed" or "mastered") ? "inProgress" : "available";
    }
}
