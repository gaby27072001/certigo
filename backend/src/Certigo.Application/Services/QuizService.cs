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
    ILearnerModelRepository learnerModels,
    IEconomyOperationRepository economyOperations) : IQuizService
{
    private static readonly string[] EconomySteps =
        ["profile", "attempt", "progress", "learnerModel", "leaderboard", "events"];

    public async Task<SubmitQuizResult> SubmitAsync(string lessonId, SubmitQuizRequest request, CancellationToken cancellationToken = default)
    {
        if (request.PublicManifestId is not null)
        {
            ContentReleaseContracts.RequireDigestId(
                request.PublicManifestId,
                "publicManifestId");
        }

        var operationId = EconomyOperationRecord.IdFor("quiz", request.ClientAttemptId);
        var existingOperation = await economyOperations.GetAsync(
            userContext.UserId,
            operationId,
            cancellationToken);
        if (existingOperation is not null)
        {
            return await ResumeEconomyOperationAsync(existingOperation, cancellationToken);
        }

        var prior = await attempts.GetByClientAttemptIdAsync(userContext.UserId, request.ClientAttemptId, cancellationToken);
        if (prior is not null)
        {
            // Attempts created before the durable journal were already projected by
            // the legacy pipeline. Replaying them would credit rewards a second time.
            return prior.Result;
        }

        SubmissionValidation.EnsureDistinctItemIds(request.Answers);

        var snapshot = await ResolveSnapshotAsync(request.PublicManifestId, cancellationToken);
        var answerKey = await content.GetAnswerKeyAsync(
                snapshot,
                request.TrackId,
                lessonId,
                cancellationToken)
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
                rejectedResult,
                snapshot.ReleaseId,
                snapshot.PublicManifestId);
            var signal = new AttemptIntegritySignal(
                "quiz",
                lessonId,
                rejectedResult.AttemptId,
                integrity.Decision.ToString(),
                integrity.RiskScore,
                integrity.Flags.Select(f => f.ToString()).ToList());
            var operation = await DurableEconomy.StartAsync(
                economyOperations,
                userContext.UserId,
                "quiz",
                request.ClientAttemptId,
                new QuizEconomyPayload(
                    rejectedAttempt,
                    Array.Empty<ConceptMastery>(),
                    null,
                    signal,
                    ProfileMutationAllowed: false),
                EconomySteps,
                now,
                cancellationToken);
            return await ResumeEconomyOperationAsync(operation, cancellationToken);
        }

        var attempt = new AttemptRecord(
            $"attempt::{request.ClientAttemptId}",
            userContext.UserId,
            request.ClientAttemptId,
            request.TrackId,
            lessonId,
            request.StartedAt,
            now,
            result,
            snapshot.ReleaseId,
            snapshot.PublicManifestId);
        var learnerModel = await BuildLearnerModelAsync(request, itemById, now, cancellationToken);
        var integritySignal = integrity.IsClean
            ? null
            : new AttemptIntegritySignal(
                "quiz",
                lessonId,
                result.AttemptId,
                integrity.Decision.ToString(),
                integrity.RiskScore,
                integrity.Flags.Select(f => f.ToString()).ToList());
        var durableOperation = await DurableEconomy.StartAsync(
            economyOperations,
            userContext.UserId,
            "quiz",
            request.ClientAttemptId,
            new QuizEconomyPayload(
                attempt,
                updatedMasteries.Values.ToArray(),
                learnerModel,
                integritySignal),
            EconomySteps,
            now,
            cancellationToken);
        return await ResumeEconomyOperationAsync(durableOperation, cancellationToken);
    }

    private async Task<ContentSnapshot> ResolveSnapshotAsync(
        string? publicManifestId,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(publicManifestId))
        {
            return await content.ResolveSnapshotAsync(publicManifestId, cancellationToken);
        }

        var snapshot = await content.ResolveActiveSnapshotAsync(cancellationToken);
        if (!snapshot.IsLegacy)
        {
            throw new RequestValidationException(
                "publicManifestId is required for a versioned quiz submission.");
        }

        return snapshot;
    }

    // Reads the learner model, observes each gradable answer (tracking the wrong
    // option chosen so the tutor can name recurring misconceptions), and persists
    // it once. Unknown items are skipped so the model only reflects real attempts.
    private async Task<LearnerModelRecord?> BuildLearnerModelAsync(
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
            return LearnerModelMap.ToRecord(userContext.UserId, request.TrackId, map, now);
        }

        return null;
    }

    private async Task<SubmitQuizResult> ResumeEconomyOperationAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken)
    {
        var payload = DurableEconomy.ReadPayload<QuizEconomyPayload>(operation);
        var profileMutationAllowed = payload.ProfileMutationAllowed
            ?? !string.Equals(
                payload.IntegritySignal?.Decision,
                IntegrityDecision.Reject.ToString(),
                StringComparison.OrdinalIgnoreCase);
        SubmitQuizResult? persistedLegacyResult = null;
        if (operation.HasCompleted("attempt")
            && string.IsNullOrWhiteSpace(operation.OutcomeJson))
        {
            persistedLegacyResult = (await attempts.GetByClientAttemptIdAsync(
                userContext.UserId,
                payload.Attempt.ClientAttemptId,
                cancellationToken))?.Result;
        }

        var canonicalLegacyResult = persistedLegacyResult ?? payload.Attempt.Result;
        var profileOutcome = await DurableEconomy.ApplyProfileOutcomeStepAsync(
            economyOperations,
            users,
            userContext.UserId,
            userContext.DisplayName,
            operation,
            profile => profileMutationAllowed
                ? ApplyQuizProfile(profile, payload.Attempt, persistedLegacyResult)
                : (profile, canonicalLegacyResult),
            outcome => outcome.Rewards,
            rewards => canonicalLegacyResult with { Rewards = rewards },
            canonicalLegacyResult,
            cancellationToken);
        operation = profileOutcome.Operation;
        var result = profileOutcome.Outcome;
        var reconciledAttempt = payload.Attempt with { Result = result };

        operation = await DurableEconomy.RunStepAsync(
            economyOperations,
            operation,
            "attempt",
            async () =>
            {
                try
                {
                    await attempts.CreateAsync(reconciledAttempt, cancellationToken);
                }
                catch (DuplicateRecordException)
                {
                    var existing = await attempts.GetByClientAttemptIdAsync(
                        userContext.UserId,
                        payload.Attempt.ClientAttemptId,
                        cancellationToken);
                    if (existing?.Result.AttemptId != result.AttemptId)
                    {
                        throw new ConcurrencyConflictException(
                            $"Attempt '{payload.Attempt.ClientAttemptId}' conflicts with another result.");
                    }
                }
            },
            cancellationToken);

        operation = await DurableEconomy.RunStepAsync(
            economyOperations,
            operation,
            "progress",
            () => DurableEconomy.UpsertMasteriesWithoutRegressionAsync(
                progress,
                userContext.UserId,
                payload.Masteries,
                cancellationToken),
            cancellationToken);

        operation = await DurableEconomy.RunStepAsync(
            economyOperations,
            operation,
            "learnerModel",
            () => payload.LearnerModel is null
                ? Task.CompletedTask
                : DurableEconomy.UpsertLearnerModelWithoutRegressionAsync(
                    learnerModels,
                    payload.LearnerModel,
                    cancellationToken),
            cancellationToken);

        operation = await DurableEconomy.RunStepAsync(
            economyOperations,
            operation,
            "leaderboard",
            () => result.Rewards.XpEarned <= 0
                ? Task.CompletedTask
                : leaderboard.AddXpAsync(
                    userContext.UserId,
                    result.Rewards.XpEarned,
                    operation.Id,
                    payload.Attempt.SubmittedAt,
                    cancellationToken),
            cancellationToken);

        await DurableEconomy.RunStepAsync(
            economyOperations,
            operation,
            "events",
            async () =>
            {
                await events.AddAsync(
                    new LearningEvent(
                        DurableEconomy.EventId(operation.Id, "quiz.submitted"),
                        userContext.UserId,
                        "quiz.submitted",
                        payload.Attempt.SubmittedAt,
                        result),
                    cancellationToken);
                if (payload.IntegritySignal is not null)
                {
                    await events.AddAsync(
                        new LearningEvent(
                            DurableEconomy.EventId(operation.Id, "attempt.flagged"),
                            userContext.UserId,
                            "attempt.flagged",
                            payload.Attempt.SubmittedAt,
                            payload.IntegritySignal),
                        cancellationToken);
                }

                if (result.Rewards.AchievementsUnlocked.Count > 0)
                {
                    await events.AddAsync(
                        new LearningEvent(
                            DurableEconomy.EventId(operation.Id, "achievement.unlocked"),
                            userContext.UserId,
                            "achievement.unlocked",
                            payload.Attempt.SubmittedAt,
                            result.Rewards.AchievementsUnlocked),
                        cancellationToken);
                }
            },
            cancellationToken);

        return result;
    }

    private static (UserProfileDto Profile, SubmitQuizResult Outcome) ApplyQuizProfile(
        UserProfileDto profile,
        AttemptRecord attempt,
        SubmitQuizResult? fixedOutcome = null)
    {
        var result = fixedOutcome ?? attempt.Result;
        var xpEarned = result.Rewards.XpEarned;
        var correctCount = result.Results.Count(item => item.Correct);
        var perfect = result.Results.Count > 0 && correctCount == result.Results.Count;
        var today = DateOnly.FromDateTime(attempt.SubmittedAt.UtcDateTime);
        var sameDay = profile.DailyXpDate == today;
        var applyDaily = (profile.DailyXpDate is null || profile.DailyXpDate <= today)
            && (profile.LastActiveDate is null || profile.LastActiveDate <= today);
        var newDailyXp = applyDaily
            ? (sameDay ? profile.DailyXpEarned : 0) + xpEarned
            : profile.DailyXpEarned;
        var goalMet = applyDaily && profile.DailyGoalXp > 0 && newDailyXp >= profile.DailyGoalXp;
        var stats = new GamificationStats(
            profile.Xp,
            profile.Level,
            profile.StreakDays,
            profile.LastActiveDate ?? DateOnly.MinValue,
            profile.FreezeTokens,
            profile.DailyGoalXp,
            sameDay ? profile.DailyXpEarned : 0);
        var streak = StreakService.UpdateStreak(stats, today, goalMet);
        var monthAnchor = new DateOnly(today.Year, today.Month, 1);
        var sameMonth = profile.MonthlyAnchor == monthAnchor;
        var applyMonth = profile.MonthlyAnchor is null || profile.MonthlyAnchor <= monthAnchor;
        var achievements = profile.Achievements is null
            ? new List<string>()
            : new List<string>(profile.Achievements);
        var newXp = profile.Xp + xpEarned;
        var newLevel = XpEngine.LevelFromXp(newXp);
        var lifetimeLessons = profile.LifetimeLessonsCompleted + 1;
        var lifetimePerfect = profile.LifetimePerfectLessons + (perfect ? 1 : 0);
        var baseGems = profile.Gems + result.Rewards.GemsEarned;
        var achievementSnapshot = new AchievementSnapshot(
            goalMet ? streak.StreakDays : profile.StreakDays,
            newXp,
            newLevel,
            lifetimeLessons,
            lifetimePerfect,
            baseGems);
        var newlyAppliedAchievements = fixedOutcome is null
            ? AchievementEngine.NewlyUnlocked(achievementSnapshot, achievements)
            : AchievementEngine.Tiers
                .Where(tier => fixedOutcome.Rewards.AchievementsUnlocked.Contains(
                        tier.Id,
                        StringComparer.Ordinal)
                    && !achievements.Contains(tier.Id, StringComparer.Ordinal))
                .ToArray();
        achievements.AddRange(newlyAppliedAchievements.Select(tier => tier.Id));
        var achievementGems = newlyAppliedAchievements.Sum(tier => tier.RewardGems);

        var updatedProfile = profile with
        {
            Xp = newXp,
            Level = newLevel,
            StreakDays = goalMet ? streak.StreakDays : profile.StreakDays,
            FreezeTokens = goalMet ? streak.FreezeTokens : profile.FreezeTokens,
            LastActiveDate = goalMet ? streak.LastActiveDate : profile.LastActiveDate,
            DailyXpEarned = newDailyXp,
            DailyXpDate = applyDaily ? today : profile.DailyXpDate,
            DailyLessonsCompleted = applyDaily
                ? (sameDay ? profile.DailyLessonsCompleted : 0) + 1
                : profile.DailyLessonsCompleted,
            DailyCorrectAnswers = applyDaily
                ? (sameDay ? profile.DailyCorrectAnswers : 0) + correctCount
                : profile.DailyCorrectAnswers,
            DailyPerfectLessons = applyDaily
                ? (sameDay ? profile.DailyPerfectLessons : 0) + (perfect ? 1 : 0)
                : profile.DailyPerfectLessons,
            DailyQuestClaims = applyDaily && !sameDay ? null : profile.DailyQuestClaims,
            LifetimeLessonsCompleted = lifetimeLessons,
            LifetimePerfectLessons = lifetimePerfect,
            Achievements = achievements,
            Gems = baseGems + achievementGems,
            MonthlyAnchor = applyMonth ? monthAnchor : profile.MonthlyAnchor,
            MonthlyXpEarned = applyMonth
                ? (sameMonth ? profile.MonthlyXpEarned : 0) + xpEarned
                : profile.MonthlyXpEarned,
            MonthlyLessonsCompleted = applyMonth
                ? (sameMonth ? profile.MonthlyLessonsCompleted : 0) + 1
                : profile.MonthlyLessonsCompleted,
            MonthlyPerfectLessons = applyMonth
                ? (sameMonth ? profile.MonthlyPerfectLessons : 0) + (perfect ? 1 : 0)
                : profile.MonthlyPerfectLessons,
        };
        var outcome = fixedOutcome ?? result with
        {
            Rewards = result.Rewards with
            {
                NewXp = newXp,
                LevelUp = newLevel > profile.Level,
                StreakExtended = streak.StreakDays > profile.StreakDays,
                AchievementsUnlocked = newlyAppliedAchievements
                    .Select(tier => tier.Id)
                    .ToList(),
            },
        };
        return (updatedProfile, outcome);
    }

    private sealed record QuizEconomyPayload(
        AttemptRecord Attempt,
        IReadOnlyList<ConceptMastery> Masteries,
        LearnerModelRecord? LearnerModel,
        AttemptIntegritySignal? IntegritySignal,
        bool? ProfileMutationAllowed = null);

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
