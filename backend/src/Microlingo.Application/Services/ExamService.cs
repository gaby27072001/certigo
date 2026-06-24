using System.Text.Json;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Exam;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Integrity;
using Microlingo.Domain.Notifications;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Readiness;
using Microlingo.Domain.Recommendation;
using Microlingo.Domain.Social;
using Microlingo.Domain.Tutor;

namespace Microlingo.Application.Services;

internal static class ExamConstants
{
    public const int DefaultLength = 20;
    public const int MinLength = 5;
    public const int MaxLength = 40;
    public const int SecondsPerItem = 75;
    public const int PassingScore = 700;
    public const int PassGemBonus = 20;
}

public interface IExamService
{
    Task<MockExamDto> GenerateAsync(MockExamRequest request, CancellationToken cancellationToken = default);
    Task<MockExamResultDto> SubmitAsync(SubmitMockExamRequest request, CancellationToken cancellationToken = default);
}

/// Adaptive mock-exam engine: composes a weighted, gap-targeting practice exam
/// from a track's answer keys and grades it server-authoritatively into a
/// Microsoft-style scaled score. Generation is read-only; submission mirrors
/// <see cref="QuizService"/>'s reward pipeline (XP, mastery, streak, leaderboard)
/// with idempotency, but pays a flat gem bonus only on a pass and does not touch
/// lesson/achievement counters (an exam is assessment, not a lesson).
public sealed class ExamService(
    IUserContext userContext,
    IClock clock,
    IContentRepository content,
    IProgressRepository progress,
    IExamAttemptRepository examAttempts,
    IAttemptRepository attempts,
    IEventRepository events,
    IUserRepository users,
    ILeaderboardRepository leaderboard) : IExamService
{
    public async Task<MockExamDto> GenerateAsync(MockExamRequest request, CancellationToken cancellationToken = default)
    {
        var track = await content.GetTrackAsync(request.TrackId, cancellationToken)
            ?? throw new InvalidOperationException($"Track '{request.TrackId}' was not found.");

        var answerKeys = await content.ListAnswerKeysAsync(request.TrackId, cancellationToken);
        var pool = answerKeys
            .SelectMany(key => key.Items.Select(item =>
                new ExamItemRef(item.ItemId, key.LessonId, key.DomainId, item.ConceptId, item.Type, item.Difficulty)))
            .ToArray();

        if (pool.Length == 0)
        {
            return new MockExamDto(
                Guid.NewGuid().ToString("n"), track.Id, track.Code, track.Title,
                0, ExamConstants.PassingScore,
                Array.Empty<MockExamBlueprintDomainDto>(), Array.Empty<MockExamItemDto>());
        }

        var cap = Math.Min(ExamConstants.MaxLength, pool.Length);
        var requested = request.Length ?? ExamConstants.DefaultLength;
        var length = Math.Clamp(requested, Math.Min(ExamConstants.MinLength, cap), cap);

        var masteries = await progress.ListMasteriesAsync(userContext.UserId, request.TrackId, cancellationToken);
        var masteryByConcept = masteries
            .GroupBy(m => m.ConceptId, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Max(m => m.MasteryScore), StringComparer.OrdinalIgnoreCase);

        var domains = track.Domains.Select(d => (d.Id, d.Name, d.Weight)).ToArray();
        var allocation = MockExamBlueprint.Apportion(domains, length);
        var seed = StableSeed(userContext.UserId, request.TrackId, DateOnly.FromDateTime(clock.UtcNow.UtcDateTime));
        var chosen = MockExamComposer.Compose(pool, allocation, masteryByConcept, seed);

        // Join chosen items to their public checks (stem + options live on the
        // answer-free lesson block, never in the key).
        var checkById = new Dictionary<string, LessonCheck>(StringComparer.OrdinalIgnoreCase);
        foreach (var lessonId in chosen.Select(i => i.LessonId).Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var lesson = await content.GetLessonAsync(request.TrackId, lessonId, cancellationToken);
            if (lesson is null)
            {
                continue;
            }

            foreach (var block in lesson.Blocks)
            {
                if (block.Check is { } check)
                {
                    checkById[check.Id] = check;
                }
            }
        }

        var items = chosen
            .Where(i => checkById.ContainsKey(i.ItemId))
            .Select(i =>
            {
                var check = checkById[i.ItemId];
                return new MockExamItemDto(i.ItemId, i.LessonId, i.DomainId, check.Type, check.Stem, check.Options);
            })
            .ToList();

        var domainMeta = track.Domains.ToDictionary(d => d.Id, d => d, StringComparer.OrdinalIgnoreCase);
        var blueprint = items
            .GroupBy(i => i.DomainId, StringComparer.OrdinalIgnoreCase)
            .Select(g =>
            {
                domainMeta.TryGetValue(g.Key, out var dm);
                return new MockExamBlueprintDomainDto(g.Key, dm?.Name ?? g.Key, dm?.Weight ?? 1.0, g.Count());
            })
            .OrderByDescending(b => b.Weight)
            .ThenBy(b => b.DomainId, StringComparer.Ordinal)
            .ToList();

        var examId = Guid.NewGuid().ToString("n");
        var timeLimit = items.Count * ExamConstants.SecondsPerItem;

        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "exam.generated",
            clock.UtcNow,
            new { examId, trackId = track.Id, length = items.Count }), cancellationToken);

        return new MockExamDto(
            examId, track.Id, track.Code, track.Title,
            timeLimit, ExamConstants.PassingScore, blueprint, items);
    }

    public async Task<MockExamResultDto> SubmitAsync(SubmitMockExamRequest request, CancellationToken cancellationToken = default)
    {
        var prior = await examAttempts.GetByClientAttemptIdAsync(userContext.UserId, request.ClientAttemptId, cancellationToken);
        if (prior is not null)
        {
            return prior.Result;
        }

        var track = await content.GetTrackAsync(request.TrackId, cancellationToken)
            ?? throw new InvalidOperationException($"Track '{request.TrackId}' was not found.");
        var answerKeys = await content.ListAnswerKeysAsync(request.TrackId, cancellationToken);

        var keyItemById = new Dictionary<string, (AnswerKeyItem Item, string LessonId, string DomainId)>(StringComparer.OrdinalIgnoreCase);
        foreach (var key in answerKeys)
        {
            foreach (var item in key.Items)
            {
                keyItemById[item.ItemId] = (item, key.LessonId, key.DomainId);
            }
        }

        var now = clock.UtcNow;
        var itemResults = new List<ItemResultDto>();
        var updatedMasteries = new Dictionary<string, ConceptMastery>(StringComparer.OrdinalIgnoreCase);
        var correctByItemId = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        var examItems = new List<ExamItemRef>();
        var xpEarned = 0;
        var correctCount = 0;

        foreach (var answer in request.Answers)
        {
            if (!keyItemById.TryGetValue(answer.ItemId, out var entry))
            {
                continue;
            }

            var item = entry.Item;
            var correct = IsCorrect(item, answer);
            correctByItemId[item.ItemId] = correct;
            examItems.Add(new ExamItemRef(item.ItemId, entry.LessonId, entry.DomainId, item.ConceptId, item.Type, item.Difficulty));
            if (correct)
            {
                correctCount++;
            }

            var before = updatedMasteries.TryGetValue(item.ConceptId, out var pending)
                ? pending
                : await progress.GetMasteryAsync(userContext.UserId, request.TrackId, item.ConceptId, cancellationToken)
                    ?? ConceptMastery.New(userContext.UserId, request.TrackId, item.ConceptId);
            var grade = ReviewScheduler.GradeFrom(correct, answer.LatencyMs);
            var after = ReviewScheduler.Apply(before, grade, now);
            updatedMasteries[item.ConceptId] = after;
            xpEarned += XpEngine.ForQuizItem(item.Type, item.Difficulty, correct, before, after);

            itemResults.Add(new ItemResultDto(
                item.ItemId,
                correct,
                item.ConceptId,
                correct ? null : item.Correct.ToList(),
                item.Explanation,
                Math.Round(after.MasteryScore - before.MasteryScore, 4)));
        }

        var domainMeta = track.Domains.ToDictionary(
            d => d.Id, d => (d.Name, d.Weight), StringComparer.OrdinalIgnoreCase);
        var score = MockExamScorer.Score(examItems, correctByItemId, domainMeta, ExamConstants.PassingScore);

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(now.UtcDateTime);
        var sameDay = profile.DailyXpDate == today;
        var newDailyXp = (sameDay ? profile.DailyXpEarned : 0) + xpEarned;
        var goalMet = profile.DailyGoalXp > 0 && newDailyXp >= profile.DailyGoalXp;

        // The mock exam awards XP too, so it feeds MonthlyXpEarned. Lessons and
        // perfect-lessons stay lesson-only, but the anchor still resets every
        // monthly counter on the first activity of a new month, whichever flow
        // fires first.
        var monthAnchor = new DateOnly(today.Year, today.Month, 1);
        var sameMonth = profile.MonthlyAnchor == monthAnchor;

        var stats = new GamificationStats(
            profile.Xp,
            profile.Level,
            profile.StreakDays,
            profile.LastActiveDate ?? DateOnly.MinValue,
            profile.FreezeTokens,
            profile.DailyGoalXp,
            sameDay ? profile.DailyXpEarned : 0);
        var newStats = StreakService.UpdateStreak(stats, today, goalMet);
        var streakExtended = goalMet && profile.LastActiveDate != today;

        var newXp = profile.Xp + xpEarned;
        var newLevel = XpEngine.LevelFromXp(newXp);
        var gemsEarned = score.Passed ? ExamConstants.PassGemBonus : 0;

        var updatedProfile = profile with
        {
            Xp = newXp,
            Level = newLevel,
            StreakDays = goalMet ? newStats.StreakDays : profile.StreakDays,
            FreezeTokens = goalMet ? newStats.FreezeTokens : profile.FreezeTokens,
            LastActiveDate = goalMet ? newStats.LastActiveDate : profile.LastActiveDate,
            DailyXpEarned = newDailyXp,
            DailyXpDate = today,
            DailyCorrectAnswers = (sameDay ? profile.DailyCorrectAnswers : 0) + correctCount,
            MonthlyAnchor = monthAnchor,
            MonthlyXpEarned = (sameMonth ? profile.MonthlyXpEarned : 0) + xpEarned,
            MonthlyLessonsCompleted = sameMonth ? profile.MonthlyLessonsCompleted : 0,
            MonthlyPerfectLessons = sameMonth ? profile.MonthlyPerfectLessons : 0,
            Gems = profile.Gems + gemsEarned
        };
        await users.UpsertAsync(updatedProfile, cancellationToken);
        await progress.UpsertMasteryBatchAsync(userContext.UserId, updatedMasteries.Values.ToArray(), cancellationToken);

        if (xpEarned > 0)
        {
            await leaderboard.AddXpAsync(userContext.UserId, xpEarned, cancellationToken);
        }

        var weakConcepts = updatedMasteries.Values
            .Where(m => m.MasteryScore < 0.5)
            .Select(m => m.ConceptId)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        var domainScores = score.Domains
            .Select(d => new ExamDomainScoreDto(d.DomainId, d.Name, d.Weight, d.Correct, d.Total, d.Pct))
            .ToList();

        var attemptId = Guid.NewGuid().ToString("n");
        var result = new MockExamResultDto(
            attemptId,
            request.ExamId,
            score.ScaledScore,
            score.Pct,
            score.Passed,
            score.PassingScore,
            score.Correct,
            score.Total,
            domainScores,
            itemResults,
            new RewardsDto(xpEarned, newXp, newLevel > profile.Level, streakExtended, gemsEarned, new List<string>()),
            weakConcepts);

        // Fenêtre de cadence (tentatives ANTÉRIEURES uniquement — la tentative courante
        // n'est pas encore persistée). En prod les tentatives d'examen partagent le conteneur
        // « attempts » avec les leçons et sont comptées par GetRecentActivityAsync ; on capture
        // donc la fenêtre AVANT CreateAsync pour ne pas compter la soumission courante
        // (l'évaluateur l'ajoute lui-même). Alimente les détecteurs anti-farming d'XP / anti-spam.
        var rateWindow = await BuildRateWindowAsync(now, cancellationToken);

        var attempt = new ExamAttemptRecord(
            $"examattempt::{request.ClientAttemptId}", userContext.UserId, request.ClientAttemptId, request.TrackId, request.ExamId,
            request.StartedAt, now, result);
        await examAttempts.CreateAsync(attempt, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "exam.submitted", now, result), cancellationToken);

        // Anti-triche (autorité serveur, §6/§15) — mode détection, comme pour le quiz :
        // on évalue la cohérence temporelle ET la cadence récente, et si le verdict n'est pas
        // « Allow » on signale une tentative d'examen incohérente SANS toucher aux récompenses.
        var integrity = AttemptIntegrityEvaluator.Evaluate(
            new AttemptTiming(
                request.StartedAt,
                now,
                request.Answers.Select(a => a.LatencyMs).ToList(),
                xpEarned),
            rateWindow);
        if (!integrity.IsClean)
        {
            await events.AddAsync(new LearningEvent(
                Guid.NewGuid().ToString("n"),
                userContext.UserId,
                "attempt.flagged",
                now,
                new AttemptIntegritySignal(
                    "exam",
                    request.ExamId,
                    attemptId,
                    integrity.Decision.ToString(),
                    integrity.RiskScore,
                    integrity.Flags.Select(f => f.ToString()).ToList())), cancellationToken);
        }

        return result;
    }

    // Fenêtre de cadence anti-triche : nombre + XP des tentatives antérieures de l'apprenant
    // (leçons ET examens) sur la dernière heure, lues depuis le conteneur « attempts » (pas de
    // Redis). Identique à QuizService pour un comportement anti-triche uniforme entre quiz et examen.
    private static readonly TimeSpan RateWindowDuration = TimeSpan.FromHours(1);

    private async Task<RateWindow> BuildRateWindowAsync(DateTimeOffset now, CancellationToken cancellationToken)
    {
        var recent = await attempts.GetRecentActivityAsync(userContext.UserId, now - RateWindowDuration, cancellationToken);
        return new RateWindow(RateWindowDuration, recent.Xp, recent.Attempts);
    }

    private static int StableSeed(string userId, string trackId, DateOnly date)
    {
        unchecked
        {
            var hash = 17;
            foreach (var c in userId)
            {
                hash = (hash * 31) + c;
            }

            foreach (var c in trackId)
            {
                hash = (hash * 31) + c;
            }

            hash = (hash * 31) + date.DayNumber;
            return hash & 0x7fffffff;
        }
    }

    private static bool IsCorrect(AnswerKeyItem item, AnswerDto answer)
    {
        var expected = item.Correct.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        var actual = answer.Selected.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        return expected.SequenceEqual(actual, StringComparer.OrdinalIgnoreCase);
    }
}
