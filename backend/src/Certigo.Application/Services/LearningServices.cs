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
            throw new TrackNotFoundException(trackId);

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
            OfficialCertificationCatalog.TitleFor(track.Code, track.Title),
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

public interface IRecommendationService
{
    Task<NextBestDto> GetNextBestAsync(string trackId, CancellationToken cancellationToken = default);
}

/// The "next best action" coach. Fuses the learner's FSRS memory state (mastery,
/// stability, due dates) with the behavioural learner model (errors, consecutive
/// errors) and the live skill-path frontier, then asks the pure
/// <see cref="RecommendationEngine"/> what to surface right now. Read-only — it
/// never mutates progress, so it is safe to call on every home-screen load. French
/// reasons are composed here so the engine stays presentation-agnostic.
public sealed class RecommendationService(
    IUserContext userContext,
    IContentRepository content,
    IProgressRepository progress,
    ILearnerModelRepository learnerModels,
    IClock clock) : IRecommendationService
{
    public async Task<NextBestDto> GetNextBestAsync(string trackId, CancellationToken cancellationToken = default)
    {
        var now = clock.UtcNow;
        var track = await content.GetTrackAsync(trackId, cancellationToken);
        if (track is null)
        {
            return new NextBestDto(trackId, now, Array.Empty<RecommendationItemDto>());
        }

        var masteries = await progress.ListMasteriesAsync(userContext.UserId, trackId, cancellationToken);
        var masteryByConcept = masteries
            .GroupBy(m => m.ConceptId, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

        var learnerRecord = await learnerModels.GetAsync(userContext.UserId, trackId, cancellationToken);
        var statByConcept = LearnerModelMap.ToMap(learnerRecord);

        var lessonIds = track.Units.SelectMany(u => u.Lessons).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        var loaded = await Task.WhenAll(lessonIds.Select(id => content.GetLessonAsync(trackId, id, cancellationToken)));
        var lessonById = loaded
            .Where(l => l is not null)
            .Select(l => l!)
            .ToDictionary(l => l.Id, StringComparer.OrdinalIgnoreCase);

        var domainWeights = track.Domains.ToDictionary(d => d.Id, d => d.Weight, StringComparer.OrdinalIgnoreCase);
        var domainNames = track.Domains.ToDictionary(d => d.Id, d => d.Name, StringComparer.OrdinalIgnoreCase);

        var conceptDomains = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var lesson in lessonById.Values)
        {
            foreach (var conceptId in GradableConcepts(lesson))
            {
                conceptDomains[conceptId] = lesson.DomainId;
            }
        }

        var lessonCandidates = BuildLessonCandidates(track, lessonById, masteryByConcept, domainWeights);
        var signals = BuildConceptSignals(conceptDomains, masteryByConcept, statByConcept, domainWeights, now);

        var ranked = RecommendationEngine.Rank(lessonCandidates, signals, now, max: 5);
        var signalByConcept = signals.ToDictionary(s => s.ConceptId, s => s, StringComparer.OrdinalIgnoreCase);

        var items = ranked
            .Select(r => ToDto(r, lessonById, domainNames, signalByConcept, now))
            .ToArray();

        return new NextBestDto(trackId, now, items);
    }

    // Mirrors PathService's frontier walk so the coach's notion of locked /
    // available / in-progress / completed / mastered is identical to the path the
    // learner sees — recommendations never point at a node the path shows as locked.
    private static List<LessonCandidate> BuildLessonCandidates(
        Track track,
        IReadOnlyDictionary<string, Lesson> lessonById,
        IReadOnlyDictionary<string, ConceptMastery> masteryByConcept,
        IReadOnlyDictionary<string, double> domainWeights)
    {
        var result = new List<LessonCandidate>();
        var previousUnitCompleted = true;
        foreach (var unit in track.Units)
        {
            var unitUnlocked = previousUnitCompleted;
            var frontierConsumed = false;
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

                var rawDone = total > 0 && tracked == total;
                var rawMastered = rawDone && avg >= 0.85;
                var rawInProgress = !rawDone && tracked > 0;

                LessonProgress lessonProgress;
                if (!unitUnlocked)
                {
                    lessonProgress = LessonProgress.Locked;
                }
                else if (rawMastered)
                {
                    lessonProgress = LessonProgress.Mastered;
                }
                else if (rawDone)
                {
                    lessonProgress = LessonProgress.Completed;
                }
                else if (!frontierConsumed)
                {
                    lessonProgress = rawInProgress ? LessonProgress.InProgress : LessonProgress.Available;
                    frontierConsumed = true;
                }
                else
                {
                    lessonProgress = LessonProgress.Locked;
                }

                if (!rawDone)
                {
                    allLessonsDone = false;
                }

                var domainId = lesson?.DomainId ?? unit.DomainId;
                result.Add(new LessonCandidate(
                    lessonId,
                    unit.Id,
                    lesson?.Title ?? lessonId,
                    domainId,
                    domainWeights.GetValueOrDefault(domainId, 0d),
                    lesson?.EstMinutes ?? 0,
                    concepts,
                    lessonProgress));
            }

            previousUnitCompleted = unitUnlocked && allLessonsDone && unit.Lessons.Count > 0;
        }

        return result;
    }

    // Fuses memory (FSRS) and behaviour (learner model) per concept. Only concepts
    // with some history are emitted; untouched concepts are reached through their
    // "start" lesson instead, so the coach never reviews something never seen.
    private static List<ConceptSignal> BuildConceptSignals(
        IReadOnlyDictionary<string, string> conceptDomains,
        IReadOnlyDictionary<string, ConceptMastery> masteryByConcept,
        IReadOnlyDictionary<string, LearnerConceptStat> statByConcept,
        IReadOnlyDictionary<string, double> domainWeights,
        DateTimeOffset now)
    {
        var signals = new List<ConceptSignal>();
        foreach (var (conceptId, domainId) in conceptDomains)
        {
            masteryByConcept.TryGetValue(conceptId, out var mastery);
            statByConcept.TryGetValue(conceptId, out var stat);

            var hasHistory = mastery is not null || (stat is not null && stat.Attempts > 0);
            if (!hasHistory)
            {
                continue;
            }

            var lastReviewed = mastery?.LastReviewedAt ?? stat?.LastSeen ?? now;
            signals.Add(new ConceptSignal(
                conceptId,
                domainId,
                domainWeights.GetValueOrDefault(domainId, 0d),
                mastery?.MasteryScore ?? 0d,
                mastery?.Stability ?? 1d,
                mastery?.DueAt ?? now,
                lastReviewed,
                stat?.Errors ?? 0,
                stat?.ConsecutiveErrors ?? 0));
        }

        return signals;
    }

    private static RecommendationItemDto ToDto(
        RecommendationCandidate r,
        IReadOnlyDictionary<string, Lesson> lessonById,
        IReadOnlyDictionary<string, string> domainNames,
        IReadOnlyDictionary<string, ConceptSignal> signalByConcept,
        DateTimeOffset now)
    {
        var domainName = domainNames.GetValueOrDefault(r.DomainId, r.DomainId);
        var riskPct = (int)Math.Round(r.ForgettingRisk * 100);
        var masteryPct = (int)Math.Round(r.MasteryScore * 100);

        return new RecommendationItemDto(
            KindWire(r.Kind),
            r.LessonId,
            r.UnitId,
            r.ConceptId,
            TitleFor(r, lessonById),
            r.DomainId,
            domainName,
            ReasonFor(r, domainName, riskPct, signalByConcept, now),
            r.EstMinutes,
            (int)Math.Round(r.Priority),
            masteryPct,
            riskPct);
    }

    private static string KindWire(RecommendationKind kind) => kind switch
    {
        RecommendationKind.Practice => "practice",
        RecommendationKind.Review => "review",
        RecommendationKind.Resume => "resume",
        _ => "start"
    };

    private static string TitleFor(RecommendationCandidate r, IReadOnlyDictionary<string, Lesson> lessonById)
    {
        if (r.LessonId is not null && lessonById.TryGetValue(r.LessonId, out var lesson))
        {
            return lesson.Title;
        }

        if (!string.IsNullOrWhiteSpace(r.ConceptId))
        {
            return Humanize(r.ConceptId!);
        }

        return r.LessonId ?? "Prochaine étape";
    }

    private static string ReasonFor(
        RecommendationCandidate r,
        string domainName,
        int riskPct,
        IReadOnlyDictionary<string, ConceptSignal> signalByConcept,
        DateTimeOffset now)
    {
        switch (r.Kind)
        {
            case RecommendationKind.Practice:
                var errors = r.ConceptId is not null && signalByConcept.TryGetValue(r.ConceptId, out var s)
                    ? s.Errors
                    : 0;
                return $"Tu butes sur ce concept ({errors} erreurs) — reprenons-le ensemble.";
            case RecommendationKind.Review:
                var overdue = r.ConceptId is not null
                    && signalByConcept.TryGetValue(r.ConceptId, out var rs)
                    && now >= rs.DueAt;
                return overdue
                    ? $"Révision due — {riskPct}% de risque d'oubli."
                    : $"À réviser : {riskPct}% de risque d'oubli.";
            case RecommendationKind.Resume:
                return "Reprends là où tu t'es arrêté.";
            default:
                return $"Nouvelle leçon pour progresser en {domainName}.";
        }
    }

    private static string Humanize(string conceptId)
    {
        var segment = conceptId;
        var colon = segment.LastIndexOf(':');
        if (colon >= 0 && colon < segment.Length - 1)
        {
            segment = segment[(colon + 1)..];
        }

        segment = segment.Replace('-', ' ').Replace('_', ' ').Trim();
        if (segment.Length == 0)
        {
            return conceptId;
        }

        return char.ToUpperInvariant(segment[0]) + segment[1..];
    }

    private static IEnumerable<string> GradableConcepts(Lesson lesson)
        => lesson.Blocks
            .Where(b => b.Check is not null)
            .Select(b => b.Check!.ConceptId)
            .Distinct(StringComparer.OrdinalIgnoreCase);
}
