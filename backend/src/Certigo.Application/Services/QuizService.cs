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

public interface IQuizService
{
    Task<SubmitQuizResult> SubmitAsync(string lessonId, SubmitQuizRequest request, CancellationToken cancellationToken = default);
}

public sealed class QuizService(
    IUserContext userContext,
    IClock clock,
    IContentRepository content,
    IProgressRepository progress,
    IAttemptRepository attempts,
    IEventRepository events,
    IUserRepository users,
    ILeaderboardRepository leaderboard,
    ILearnerModelRepository learnerModels) : IQuizService
{
    public async Task<SubmitQuizResult> SubmitAsync(string lessonId, SubmitQuizRequest request, CancellationToken cancellationToken = default)
    {
        var prior = await attempts.GetByClientAttemptIdAsync(userContext.UserId, request.ClientAttemptId, cancellationToken);
        if (prior is not null)
        {
            return prior.Result;
        }

        var answerKey = await content.GetAnswerKeyAsync(request.TrackId, lessonId, cancellationToken)
            ?? throw new InvalidOperationException($"Answer key for lesson '{lessonId}' was not found.");
        var itemById = answerKey.Items.ToDictionary(i => i.ItemId, StringComparer.OrdinalIgnoreCase);
        var now = clock.UtcNow;
        var itemResults = new List<ItemResultDto>();
        var updatedMasteries = new Dictionary<string, ConceptMastery>(StringComparer.OrdinalIgnoreCase);
        var correctCount = 0;
        var xpEarned = 0;

        foreach (var answer in request.Answers)
        {
            if (!itemById.TryGetValue(answer.ItemId, out var item))
            {
                continue;
            }

            var correct = IsCorrect(item, answer);
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

        // Profile-dependent outcome computed as a pure function of a profile
        // snapshot, so it can be re-applied verbatim onto a fresher snapshot if a
        // concurrent writer bumps the profile between our read and our write.
        (UserProfileDto Updated, SubmitQuizResult Result, List<string> UnlockedIds) ComputeOutcome(UserProfileDto profile)
        {
            var scorePct = itemResults.Count == 0 ? 0 : (int)Math.Round(100d * correctCount / itemResults.Count);
            var perfect = itemResults.Count > 0 && correctCount == itemResults.Count;
            var gemsEarned = correctCount + (perfect ? 5 : 0);

            var today = DateOnly.FromDateTime(now.UtcDateTime);
            var sameDay = profile.DailyXpDate == today;
            var newDailyXp = (sameDay ? profile.DailyXpEarned : 0) + xpEarned;
            var goalMet = profile.DailyGoalXp > 0 && newDailyXp >= profile.DailyGoalXp;

            // Monthly accumulators feed the season challenge. They roll over at the
            // month boundary exactly like the daily counters roll over at midnight.
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

            // Lifetime counters and post-quiz stats feed the achievement evaluation.
            // Achievement gems are added on top of quiz gems but kept out of
            // RewardsDto.GemsEarned (which reports only what the lesson itself paid).
            var lifetimeLessons = profile.LifetimeLessonsCompleted + 1;
            var lifetimePerfect = profile.LifetimePerfectLessons + (perfect ? 1 : 0);
            var newStreakDays = goalMet ? newStats.StreakDays : profile.StreakDays;
            var gemsBeforeAchievements = profile.Gems + gemsEarned;

            var snapshot = new AchievementSnapshot(newStreakDays, newXp, newLevel, lifetimeLessons, lifetimePerfect, gemsBeforeAchievements);
            var alreadyUnlocked = profile.Achievements ?? new List<string>();
            var newlyUnlocked = AchievementEngine.NewlyUnlocked(snapshot, alreadyUnlocked);
            var achievementGems = newlyUnlocked.Sum(t => t.RewardGems);
            var unlocked = newlyUnlocked.Select(t => t.Id).ToList();
            var allAchievements = newlyUnlocked.Count == 0
                ? profile.Achievements
                : alreadyUnlocked.Concat(unlocked).ToList();

            var updated = profile with
            {
                Xp = newXp,
                Level = newLevel,
                StreakDays = goalMet ? newStats.StreakDays : profile.StreakDays,
                FreezeTokens = goalMet ? newStats.FreezeTokens : profile.FreezeTokens,
                LastActiveDate = goalMet ? newStats.LastActiveDate : profile.LastActiveDate,
                DailyXpEarned = newDailyXp,
                DailyXpDate = today,
                DailyLessonsCompleted = (sameDay ? profile.DailyLessonsCompleted : 0) + 1,
                DailyCorrectAnswers = (sameDay ? profile.DailyCorrectAnswers : 0) + correctCount,
                DailyPerfectLessons = (sameDay ? profile.DailyPerfectLessons : 0) + (perfect ? 1 : 0),
                DailyQuestClaims = sameDay ? profile.DailyQuestClaims : null,
                LifetimeLessonsCompleted = lifetimeLessons,
                LifetimePerfectLessons = lifetimePerfect,
                Achievements = allAchievements,
                Gems = gemsBeforeAchievements + achievementGems,
                MonthlyAnchor = monthAnchor,
                MonthlyXpEarned = (sameMonth ? profile.MonthlyXpEarned : 0) + xpEarned,
                MonthlyLessonsCompleted = (sameMonth ? profile.MonthlyLessonsCompleted : 0) + 1,
                MonthlyPerfectLessons = (sameMonth ? profile.MonthlyPerfectLessons : 0) + (perfect ? 1 : 0)
            };

            var outcomeResult = new SubmitQuizResult(
                Guid.NewGuid().ToString("n"),
                scorePct,
                itemResults,
                new RewardsDto(xpEarned, newXp, newLevel > profile.Level, streakExtended, gemsEarned, unlocked),
                updatedMasteries.Values.Where(m => m.MasteryScore < 0.5).Select(m => m.ConceptId).Distinct().ToList(),
                updatedMasteries.Values.OrderBy(m => m.DueAt).Select(m => (DateTimeOffset?)m.DueAt).FirstOrDefault());

            return (updated, outcomeResult, unlocked);
        }

        var p0 = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var outcome = ComputeOutcome(p0);
        var result = outcome.Result;

        // Recent-activity rate window (PRIOR attempts only — this one isn't recorded
        // yet) feeds the anti-cheat XP-farming / submission-spam detectors.
        var rateWindow = await BuildRateWindowAsync(now, cancellationToken);

        // Anti-triche (autorité serveur, §6/§15) — mode SANCTION : on évalue la
        // cohérence temporelle ET la cadence récente AVANT de créditer quoi que ce soit.
        // Reject ⇒ tentative non récompensée ; Flag ⇒ détection seule (récompenses créditées).
        var integrity = AttemptIntegrityEvaluator.Evaluate(
            new AttemptTiming(
                request.StartedAt,
                now,
                request.Answers.Select(a => a.LatencyMs).ToList(),
                xpEarned),
            rateWindow);

        // Verdict Reject : on supprime TOUTES les récompenses (0 XP/gems, pas de level-up,
        // ni leaderboard ni upsert profil), on persiste la tentative à zéro pour l'audit et
        // l'idempotence, et on émet le signal d'intégrité. Le profil reste intact.
        if (integrity.Decision == IntegrityDecision.Reject)
        {
            var rejectedResult = result with
            {
                Rewards = new RewardsDto(0, p0.Xp, false, false, 0, new List<string>())
            };
            var rejectedAttempt = new AttemptRecord(
                $"attempt::{request.ClientAttemptId}",
                userContext.UserId,
                request.ClientAttemptId,
                request.TrackId,
                lessonId,
                request.StartedAt,
                now,
                rejectedResult);
            try
            {
                await attempts.CreateAsync(rejectedAttempt, cancellationToken);
            }
            catch (DuplicateRecordException)
            {
                var winner = await attempts.GetByClientAttemptIdAsync(userContext.UserId, request.ClientAttemptId, cancellationToken);
                if (winner is not null)
                {
                    return winner.Result;
                }

                throw new ConcurrencyConflictException(
                    $"Attempt '{request.ClientAttemptId}' is being processed concurrently.");
            }

            await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "quiz.submitted", now, rejectedResult), cancellationToken);
            await events.AddAsync(new LearningEvent(
                Guid.NewGuid().ToString("n"),
                userContext.UserId,
                "attempt.flagged",
                now,
                new AttemptIntegritySignal(
                    "quiz",
                    lessonId,
                    rejectedResult.AttemptId,
                    integrity.Decision.ToString(),
                    integrity.RiskScore,
                    integrity.Flags.Select(f => f.ToString()).ToList())), cancellationToken);

            return rejectedResult;
        }

        // Atomic, idempotent reservation of the attempt BEFORE crediting the
        // profile. The id is derived from clientAttemptId, so a replayed or
        // concurrent create loses the race and returns the winner's result — the
        // economy is never credited twice. Recording the attempt first makes the
        // only failure direction a rare, recoverable lost reward, never a double
        // award (the safe direction for an economy).
        var attempt = new AttemptRecord(
            $"attempt::{request.ClientAttemptId}",
            userContext.UserId,
            request.ClientAttemptId,
            request.TrackId,
            lessonId,
            request.StartedAt,
            now,
            result);
        try
        {
            await attempts.CreateAsync(attempt, cancellationToken);
        }
        catch (DuplicateRecordException)
        {
            var winner = await attempts.GetByClientAttemptIdAsync(userContext.UserId, request.ClientAttemptId, cancellationToken);
            if (winner is not null)
            {
                return winner.Result;
            }

            throw new ConcurrencyConflictException(
                $"Attempt '{request.ClientAttemptId}' is being processed concurrently.");
        }

        // Credit the profile under optimistic concurrency. On a conflict (another
        // writer changed the profile after our read), re-read and re-apply the same
        // deterministic outcome so the reward is never lost.
        try
        {
            await users.UpsertAsync(outcome.Updated, cancellationToken);
        }
        catch (ConcurrencyConflictException)
        {
            await OptimisticConcurrency.ExecuteAsync(async () =>
            {
                var latest = await users.GetAsync(userContext.UserId, cancellationToken)
                    ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
                await users.UpsertAsync(ComputeOutcome(latest).Updated, cancellationToken);
            }, cancellationToken: cancellationToken);
        }

        await progress.UpsertMasteryBatchAsync(userContext.UserId, updatedMasteries.Values.ToArray(), cancellationToken);

        // Continuous learning: fold every answered item into the per-user learner
        // model so the AI tutor's personalisation sharpens with each practice
        // session. Idempotent overall — a replayed attempt short-circuits above.
        await RecordLearnerObservationsAsync(request, itemById, now, cancellationToken);

        if (xpEarned > 0)
        {
            await leaderboard.AddXpAsync(userContext.UserId, xpEarned, cancellationToken);
        }

        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "quiz.submitted", now, result), cancellationToken);

        // Anti-triche — mode SANCTION : ici le verdict ne peut être que Allow ou Flag
        // (Reject a déjà court-circuité plus haut sans créditer). Flag = détection seule :
        // récompenses conservées + signal `attempt.flagged` pour audit/ML.
        if (!integrity.IsClean)
        {
            await events.AddAsync(new LearningEvent(
                Guid.NewGuid().ToString("n"),
                userContext.UserId,
                "attempt.flagged",
                now,
                new AttemptIntegritySignal(
                    "quiz",
                    lessonId,
                    result.AttemptId,
                    integrity.Decision.ToString(),
                    integrity.RiskScore,
                    integrity.Flags.Select(f => f.ToString()).ToList())), cancellationToken);
        }

        if (outcome.UnlockedIds.Count > 0)
        {
            await events.AddAsync(new LearningEvent(
                Guid.NewGuid().ToString("n"),
                userContext.UserId,
                "achievement.unlocked",
                now,
                outcome.UnlockedIds), cancellationToken);
        }

        return result;
    }

    // Reads the learner model, observes each gradable answer (tracking the wrong
    // option chosen so the tutor can name recurring misconceptions), and persists
    // it once. Unknown items are skipped so the model only reflects real attempts.
    private async Task RecordLearnerObservationsAsync(
        SubmitQuizRequest request,
        IReadOnlyDictionary<string, AnswerKeyItem> itemById,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var record = await learnerModels.GetAsync(userContext.UserId, request.TrackId, cancellationToken);
        var map = LearnerModelMap.ToMap(record);
        var changed = false;

        foreach (var answer in request.Answers)
        {
            if (!itemById.TryGetValue(answer.ItemId, out var item))
            {
                continue;
            }

            var correct = IsCorrect(item, answer);
            var chosenWrong = correct ? null : answer.Selected?.FirstOrDefault();
            map.TryGetValue(item.ConceptId, out var prior);
            map[item.ConceptId] = LearnerModel.Observe(prior, item.ConceptId, correct, chosenWrong, now);
            changed = true;
        }

        if (changed)
        {
            await learnerModels.UpsertAsync(
                LearnerModelMap.ToRecord(userContext.UserId, request.TrackId, map, now), cancellationToken);
        }
    }

    // Anti-cheat rate window: count + XP of the learner's prior attempts (lesson and
    // exam) over the trailing hour, sourced from the attempts container (no Redis).
    private static readonly TimeSpan RateWindowDuration = TimeSpan.FromHours(1);

    private async Task<RateWindow> BuildRateWindowAsync(DateTimeOffset now, CancellationToken cancellationToken)
    {
        var recent = await attempts.GetRecentActivityAsync(userContext.UserId, now - RateWindowDuration, cancellationToken);
        return new RateWindow(RateWindowDuration, recent.Xp, recent.Attempts);
    }

    private static bool IsCorrect(AnswerKeyItem item, AnswerDto answer)
    {
        var expected = item.Correct.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        var actual = answer.Selected.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        return expected.SequenceEqual(actual, StringComparer.OrdinalIgnoreCase);
    }
}

/// Maps the persisted <see cref="LearnerModelRecord"/> to and from the working
/// per-concept dictionary the services mutate. Deterministic ordering keeps the
/// stored document stable across writes.
internal static class LearnerModelMap
{
    public static Dictionary<string, LearnerConceptStat> ToMap(LearnerModelRecord? record)
        => record is null
            ? new Dictionary<string, LearnerConceptStat>(StringComparer.OrdinalIgnoreCase)
            : record.Concepts.ToDictionary(c => c.ConceptId, c => c, StringComparer.OrdinalIgnoreCase);

    public static LearnerModelRecord ToRecord(
        string userId,
        string trackId,
        IReadOnlyDictionary<string, LearnerConceptStat> map,
        DateTimeOffset updatedAt)
        => new(
            userId,
            trackId,
            map.Values.OrderBy(c => c.ConceptId, StringComparer.Ordinal).ToArray(),
            updatedAt);
}
