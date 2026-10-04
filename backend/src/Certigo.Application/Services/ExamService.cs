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

internal static class ExamConstants
{
    public const int DefaultLength = 20;
    public const int MinLength = 5;
    public const int MaxLength = 40;
    public const int SecondsPerItem = 75;
    public const int PassingScore = 700;
    public const int PassGemBonus = 20;
    public const int SubmissionGraceSeconds = 5 * 60;
    public const int RetentionAfterExpirySeconds = 24 * 60 * 60;
}

public interface IExamService
{
    Task<MockExamDto> GenerateAsync(MockExamRequest request, CancellationToken cancellationToken = default);
    Task<MockExamResultDto> SubmitAsync(SubmitMockExamRequest request, CancellationToken cancellationToken = default);
}

/// Adaptive mock-exam engine: composes a weighted, gap-targeting practice exam
/// from a track's answer keys and grades it server-authoritatively into a
/// Microsoft-style scaled score. Generation persists the server-issued item set;
/// submission mirrors
/// <see cref="QuizService"/>'s reward pipeline (XP, mastery, streak, leaderboard)
/// with idempotency, but pays a flat gem bonus only on a pass and does not touch
/// lesson/achievement counters (an exam is assessment, not a lesson).
public sealed class ExamService(
    IUserContext userContext,
    IClock clock,
    IContentRepository content,
    IProgressRepository progress,
    IExamAttemptRepository examAttempts,
    IExamRepository exams,
    IAttemptRepository attempts,
    IEventRepository events,
    IUserRepository users,
    ILeaderboardRepository leaderboard,
    IEconomyOperationRepository economyOperations) : IExamService
{
    private static readonly string[] EconomySteps =
        ["profile", "attempt", "progress", "leaderboard", "events"];

    public async Task<MockExamDto> GenerateAsync(MockExamRequest request, CancellationToken cancellationToken = default)
    {
        var now = clock.UtcNow;
        var snapshot = await ResolveGenerationSnapshotAsync(request.PublicManifestId, cancellationToken);
        var track = await content.GetTrackAsync(snapshot, request.TrackId, cancellationToken)
            ?? throw new InvalidOperationException($"Track '{request.TrackId}' was not found.");

        var answerKeys = await content.ListAnswerKeysAsync(snapshot, request.TrackId, cancellationToken);
        var pool = answerKeys
            .SelectMany(key => key.Items.Select(item =>
                new ExamItemRef(item.ItemId, key.LessonId, key.DomainId, item.ConceptId, item.Type, item.Difficulty)))
            .ToArray();

        if (pool.Length == 0)
        {
            var emptyExamId = Guid.NewGuid().ToString("n");
            await PersistGeneratedExamAsync(
                emptyExamId,
                track.Id,
                Array.Empty<string>(),
                0,
                now,
                snapshot,
                cancellationToken);
            return new MockExamDto(
                emptyExamId, track.Id, track.Code, OfficialCertificationCatalog.TitleFor(track.Code, track.Title),
                0, ExamConstants.PassingScore,
                Array.Empty<MockExamBlueprintDomainDto>(),
                Array.Empty<MockExamItemDto>(),
                snapshot.PublicManifestId);
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
        var seed = StableSeed(userContext.UserId, request.TrackId, DateOnly.FromDateTime(now.UtcDateTime));
        var chosen = MockExamComposer.Compose(pool, allocation, masteryByConcept, seed);

        // Join chosen items to their public checks (stem + options live on the
        // answer-free lesson block, never in the key).
        var checkById = new Dictionary<string, LessonCheck>(StringComparer.OrdinalIgnoreCase);
        foreach (var lessonId in chosen.Select(i => i.LessonId).Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var lesson = await content.GetLessonAsync(
                snapshot,
                request.TrackId,
                lessonId,
                cancellationToken);
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

        await PersistGeneratedExamAsync(
            examId,
            track.Id,
            items.Select(item => item.ItemId).ToArray(),
            timeLimit,
            now,
            snapshot,
            cancellationToken);

        return new MockExamDto(
            examId, track.Id, track.Code, OfficialCertificationCatalog.TitleFor(track.Code, track.Title),
            timeLimit, ExamConstants.PassingScore, blueprint, items, snapshot.PublicManifestId);
    }

    public async Task<MockExamResultDto> SubmitAsync(SubmitMockExamRequest request, CancellationToken cancellationToken = default)
    {
        var operationId = EconomyOperationRecord.IdFor("exam", request.ExamId);
        var existingOperation = await economyOperations.GetAsync(
            userContext.UserId,
            operationId,
            cancellationToken);
        if (existingOperation is not null)
        {
            return await ResumeEconomyOperationAsync(existingOperation, cancellationToken);
        }

        var prior = await examAttempts.GetByClientAttemptIdAsync(userContext.UserId, request.ClientAttemptId, cancellationToken);
        if (prior is not null)
        {
            return prior.Result;
        }

        var priorExamAttempt = await examAttempts.GetByExamIdAsync(
            userContext.UserId,
            request.ExamId,
            cancellationToken);
        if (priorExamAttempt is not null)
        {
            return priorExamAttempt.Result;
        }

        var now = clock.UtcNow;
        var exam = await exams.GetAsync(userContext.UserId, request.ExamId, cancellationToken)
            ?? throw new RequestValidationException(
                $"Exam '{request.ExamId}' is invalid or does not belong to the current user.");
        if (!string.Equals(exam.TrackId, request.TrackId, StringComparison.OrdinalIgnoreCase))
        {
            throw new RequestValidationException(
                $"Exam '{request.ExamId}' was not issued for track '{request.TrackId}'.");
        }

        if (now >= exam.ExpiresAt)
        {
            throw new RequestValidationException($"Exam '{request.ExamId}' has expired.");
        }

        var snapshot = exam.PublicManifestId is null
            ? ContentSnapshot.Legacy
            : await content.ResolveSnapshotAsync(exam.PublicManifestId, cancellationToken);
        if (!string.Equals(snapshot.ReleaseId, exam.ReleaseId, StringComparison.Ordinal))
        {
            throw new ContentReleaseStateException(
                $"Exam '{request.ExamId}' content release no longer resolves consistently.");
        }

        SubmissionValidation.EnsureDistinctItemIds(request.Answers);
        var issuedItemIds = new HashSet<string>(exam.ItemIds, StringComparer.OrdinalIgnoreCase);
        var unissuedItemIds = request.Answers
            .Where(answer => !issuedItemIds.Contains(answer.ItemId))
            .Select(answer => answer.ItemId)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(itemId => itemId, StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (unissuedItemIds.Length > 0)
        {
            throw new RequestValidationException(
                $"Item id(s) were not issued for exam '{request.ExamId}': " +
                $"{string.Join(", ", unissuedItemIds)}.");
        }

        var track = await content.GetTrackAsync(snapshot, request.TrackId, cancellationToken)
            ?? throw new InvalidOperationException($"Track '{request.TrackId}' was not found.");
        var answerKeys = await content.ListAnswerKeysAsync(snapshot, request.TrackId, cancellationToken);

        var keyItemById = new Dictionary<string, (AnswerKeyItem Item, string LessonId, string DomainId)>(StringComparer.OrdinalIgnoreCase);
        foreach (var key in answerKeys)
        {
            foreach (var item in key.Items)
            {
                keyItemById[item.ItemId] = (item, key.LessonId, key.DomainId);
            }
        }

        var missingAnswerKeyItemIds = exam.ItemIds
            .Where(itemId => !keyItemById.ContainsKey(itemId))
            .OrderBy(itemId => itemId, StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (missingAnswerKeyItemIds.Length > 0)
        {
            throw new RequestValidationException(
                $"Exam '{request.ExamId}' can no longer be graded because its answer key changed.");
        }

        var itemResults = new List<ItemResultDto>();
        var updatedMasteries = new Dictionary<string, ConceptMastery>(StringComparer.OrdinalIgnoreCase);
        var correctByItemId = exam.ItemIds.ToDictionary(
            itemId => itemId,
            _ => false,
            StringComparer.OrdinalIgnoreCase);
        var examItems = exam.ItemIds
            .Select(itemId =>
            {
                var entry = keyItemById[itemId];
                return new ExamItemRef(
                    entry.Item.ItemId,
                    entry.LessonId,
                    entry.DomainId,
                    entry.Item.ConceptId,
                    entry.Item.Type,
                    entry.Item.Difficulty);
            })
            .ToArray();
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

        // Récompense déterministe extraite en fonction PURE : elle recalcule tous les
        // deltas (XP/niveau/streak/mensuel/gems) à partir du SNAPSHOT passé, sans capturer
        // le profil lu. Cela permet, sur conflit de concurrence optimiste (412), de relire
        // le profil frais et de ré-appliquer exactement le même gain — cf. wrap de l'upsert.
        (UserProfileDto Updated, int NewXp, int NewLevel, bool StreakExtended, int GemsEarned) ComputeOutcome(UserProfileDto snapshot)
        {
            var today = DateOnly.FromDateTime(now.UtcDateTime);
            var sameDay = snapshot.DailyXpDate == today;
            var newDailyXp = (sameDay ? snapshot.DailyXpEarned : 0) + xpEarned;
            var goalMet = snapshot.DailyGoalXp > 0 && newDailyXp >= snapshot.DailyGoalXp;

            // The mock exam awards XP too, so it feeds MonthlyXpEarned. Lessons and
            // perfect-lessons stay lesson-only, but the anchor still resets every
            // monthly counter on the first activity of a new month, whichever flow
            // fires first.
            var monthAnchor = new DateOnly(today.Year, today.Month, 1);
            var sameMonth = snapshot.MonthlyAnchor == monthAnchor;

            var stats = new GamificationStats(
                snapshot.Xp,
                snapshot.Level,
                snapshot.StreakDays,
                snapshot.LastActiveDate ?? DateOnly.MinValue,
                snapshot.FreezeTokens,
                snapshot.DailyGoalXp,
                sameDay ? snapshot.DailyXpEarned : 0);
            var newStats = StreakService.UpdateStreak(stats, today, goalMet);
            var streakExtended = goalMet && snapshot.LastActiveDate != today;

            var newXp = snapshot.Xp + xpEarned;
            var newLevel = XpEngine.LevelFromXp(newXp);
            var gemsEarned = score.Passed ? ExamConstants.PassGemBonus : 0;

            var updated = snapshot with
            {
                Xp = newXp,
                Level = newLevel,
                StreakDays = goalMet ? newStats.StreakDays : snapshot.StreakDays,
                FreezeTokens = goalMet ? newStats.FreezeTokens : snapshot.FreezeTokens,
                LastActiveDate = goalMet ? newStats.LastActiveDate : snapshot.LastActiveDate,
                DailyXpEarned = newDailyXp,
                DailyXpDate = today,
                DailyCorrectAnswers = (sameDay ? snapshot.DailyCorrectAnswers : 0) + correctCount,
                MonthlyAnchor = monthAnchor,
                MonthlyXpEarned = (sameMonth ? snapshot.MonthlyXpEarned : 0) + xpEarned,
                MonthlyLessonsCompleted = sameMonth ? snapshot.MonthlyLessonsCompleted : 0,
                MonthlyPerfectLessons = sameMonth ? snapshot.MonthlyPerfectLessons : 0,
                Gems = snapshot.Gems + gemsEarned
            };

            return (updated, newXp, newLevel, streakExtended, gemsEarned);
        }

        var outcome = ComputeOutcome(profile);
        var newXp = outcome.NewXp;
        var newLevel = outcome.NewLevel;
        var streakExtended = outcome.StreakExtended;
        var gemsEarned = outcome.GemsEarned;

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

        // Anti-triche (autorité serveur, §6/§15) — évaluée AVANT tout crédit : cohérence
        // temporelle + cadence récente. Reject (signal dur : horloge falsifiée, vitesse bot)
        // supprime les récompenses ; Flag (cadence) reste en détection (récompenses créditées).
        var integrity = AttemptIntegrityEvaluator.Evaluate(
            new AttemptTiming(
                request.StartedAt,
                now,
                request.Answers.Select(a => a.LatencyMs).ToList(),
                xpEarned),
            rateWindow);

        if (integrity.Decision == IntegrityDecision.Reject)
        {
            // Sanction : tentative persistée à zéro récompense, aucun upsert profil/leaderboard.
            var suppressedResult = result with
            {
                Rewards = new RewardsDto(0, profile.Xp, false, false, 0, new List<string>())
            };
            var rejectedAttempt = new ExamAttemptRecord(
                $"examattempt::{request.ExamId}", userContext.UserId, request.ClientAttemptId, request.TrackId, request.ExamId,
                request.StartedAt, now, suppressedResult, snapshot.ReleaseId, snapshot.PublicManifestId);
            var signal = new AttemptIntegritySignal(
                "exam",
                request.ExamId,
                attemptId,
                integrity.Decision.ToString(),
                integrity.RiskScore,
                integrity.Flags.Select(f => f.ToString()).ToList());
            var rejectedOperation = await DurableEconomy.StartAsync(
                economyOperations,
                userContext.UserId,
                "exam",
                request.ExamId,
                new ExamEconomyPayload(
                    rejectedAttempt,
                    Array.Empty<ConceptMastery>(),
                    signal,
                    ProfileMutationAllowed: false),
                EconomySteps,
                now,
                cancellationToken);
            return await ResumeEconomyOperationAsync(rejectedOperation, cancellationToken);
        }

        var attempt = new ExamAttemptRecord(
            $"examattempt::{request.ExamId}", userContext.UserId, request.ClientAttemptId, request.TrackId, request.ExamId,
            request.StartedAt, now, result, snapshot.ReleaseId, snapshot.PublicManifestId);
        var integritySignal = integrity.IsClean
            ? null
            : new AttemptIntegritySignal(
                "exam",
                request.ExamId,
                attemptId,
                integrity.Decision.ToString(),
                integrity.RiskScore,
                integrity.Flags.Select(f => f.ToString()).ToList());
        var operation = await DurableEconomy.StartAsync(
            economyOperations,
            userContext.UserId,
            "exam",
            request.ExamId,
            new ExamEconomyPayload(attempt, updatedMasteries.Values.ToArray(), integritySignal),
            EconomySteps,
            now,
            cancellationToken);
        return await ResumeEconomyOperationAsync(operation, cancellationToken);
    }

    private async Task<MockExamResultDto> ResumeEconomyOperationAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken)
    {
        var payload = DurableEconomy.ReadPayload<ExamEconomyPayload>(operation);
        var profileMutationAllowed = payload.ProfileMutationAllowed
            ?? !string.Equals(
                payload.IntegritySignal?.Decision,
                IntegrityDecision.Reject.ToString(),
                StringComparison.OrdinalIgnoreCase);
        MockExamResultDto? persistedLegacyResult = null;
        if (operation.HasCompleted("attempt")
            && string.IsNullOrWhiteSpace(operation.OutcomeJson))
        {
            persistedLegacyResult = (await examAttempts.GetByExamIdAsync(
                userContext.UserId,
                payload.Attempt.ExamId,
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
                ? ApplyExamProfile(profile, payload.Attempt, persistedLegacyResult)
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
                    await examAttempts.CreateAsync(reconciledAttempt, cancellationToken);
                }
                catch (DuplicateRecordException)
                {
                    var existing = await examAttempts.GetByExamIdAsync(
                        userContext.UserId,
                        payload.Attempt.ExamId,
                        cancellationToken);
                    if (existing?.Result.AttemptId != result.AttemptId)
                    {
                        throw new ConcurrencyConflictException(
                            $"Exam '{payload.Attempt.ExamId}' conflicts with another result.");
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
                        DurableEconomy.EventId(operation.Id, "exam.submitted"),
                        userContext.UserId,
                        "exam.submitted",
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
            },
            cancellationToken);

        return result;
    }

    private static (UserProfileDto Profile, MockExamResultDto Outcome) ApplyExamProfile(
        UserProfileDto profile,
        ExamAttemptRecord attempt,
        MockExamResultDto? fixedOutcome = null)
    {
        var result = fixedOutcome ?? attempt.Result;
        var xpEarned = result.Rewards.XpEarned;
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
        var newXp = profile.Xp + xpEarned;

        var updatedProfile = profile with
        {
            Xp = newXp,
            Level = XpEngine.LevelFromXp(newXp),
            StreakDays = goalMet ? streak.StreakDays : profile.StreakDays,
            FreezeTokens = goalMet ? streak.FreezeTokens : profile.FreezeTokens,
            LastActiveDate = goalMet ? streak.LastActiveDate : profile.LastActiveDate,
            DailyXpEarned = newDailyXp,
            DailyXpDate = applyDaily ? today : profile.DailyXpDate,
            DailyCorrectAnswers = applyDaily
                ? (sameDay ? profile.DailyCorrectAnswers : 0) + result.Correct
                : profile.DailyCorrectAnswers,
            MonthlyAnchor = applyMonth ? monthAnchor : profile.MonthlyAnchor,
            MonthlyXpEarned = applyMonth
                ? (sameMonth ? profile.MonthlyXpEarned : 0) + xpEarned
                : profile.MonthlyXpEarned,
            MonthlyLessonsCompleted = applyMonth
                ? (sameMonth ? profile.MonthlyLessonsCompleted : 0)
                : profile.MonthlyLessonsCompleted,
            MonthlyPerfectLessons = applyMonth
                ? (sameMonth ? profile.MonthlyPerfectLessons : 0)
                : profile.MonthlyPerfectLessons,
            Gems = profile.Gems + result.Rewards.GemsEarned,
        };
        var outcome = fixedOutcome ?? result with
        {
            Rewards = result.Rewards with
            {
                NewXp = newXp,
                LevelUp = XpEngine.LevelFromXp(newXp) > profile.Level,
                StreakExtended = streak.StreakDays > profile.StreakDays,
            },
        };
        return (updatedProfile, outcome);
    }

    private sealed record ExamEconomyPayload(
        ExamAttemptRecord Attempt,
        IReadOnlyList<ConceptMastery> Masteries,
        AttemptIntegritySignal? IntegritySignal,
        bool? ProfileMutationAllowed = null);

    // Fenêtre de cadence anti-triche : nombre + XP des tentatives antérieures de l'apprenant
    // (leçons ET examens) sur la dernière heure, lues depuis le conteneur « attempts » (pas de
    // Redis). Identique à QuizService pour un comportement anti-triche uniforme entre quiz et examen.
    private static readonly TimeSpan RateWindowDuration = TimeSpan.FromHours(1);

    private async Task<RateWindow> BuildRateWindowAsync(DateTimeOffset now, CancellationToken cancellationToken)
    {
        var recent = await attempts.GetRecentActivityAsync(userContext.UserId, now - RateWindowDuration, cancellationToken);
        return new RateWindow(RateWindowDuration, recent.Xp, recent.Attempts);
    }

    private async Task PersistGeneratedExamAsync(
        string examId,
        string trackId,
        IReadOnlyList<string> itemIds,
        int durationSeconds,
        DateTimeOffset createdAt,
        ContentSnapshot snapshot,
        CancellationToken cancellationToken)
    {
        var validitySeconds = Math.Max(durationSeconds, 0) + ExamConstants.SubmissionGraceSeconds;
        var expiresAt = createdAt.AddSeconds(validitySeconds);
        var record = new ExamRecord(
            $"exam::{examId}",
            userContext.UserId,
            examId,
            trackId,
            itemIds,
            createdAt,
            durationSeconds,
            expiresAt,
            validitySeconds + ExamConstants.RetentionAfterExpirySeconds,
            snapshot.ReleaseId,
            snapshot.PublicManifestId);
        await exams.CreateAsync(record, cancellationToken);
        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "exam.generated",
            createdAt,
            new
            {
                examId,
                trackId,
                length = itemIds.Count,
                durationSeconds,
                expiresAt,
                snapshot.ReleaseId,
                snapshot.PublicManifestId,
            }),
            cancellationToken);
    }

    private async Task<ContentSnapshot> ResolveGenerationSnapshotAsync(
        string? publicManifestId,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(publicManifestId))
        {
            return await content.ResolveSnapshotAsync(publicManifestId, cancellationToken);
        }

        var snapshot = await content.ResolveActiveSnapshotAsync(cancellationToken);
        return snapshot;
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

    private static bool IsCorrect(AnswerKeyItem item, AnswerDto answer) =>
        AnswerGrading.IsCorrect(item.Type, item.Correct, answer.Selected);
}
