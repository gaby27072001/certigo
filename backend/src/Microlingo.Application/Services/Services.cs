using System.Text.Json;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Exam;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Readiness;
using Microlingo.Domain.Social;
using Microlingo.Domain.Tutor;

namespace Microlingo.Application.Services;

public interface IUserService
{
    Task<UserProfileDto> GetOrProvisionAsync(CancellationToken cancellationToken = default);
}

public sealed class UserService(IUserContext userContext, IUserRepository users) : IUserService
{
    public async Task<UserProfileDto> GetOrProvisionAsync(CancellationToken cancellationToken = default)
    {
        var existing = await users.GetAsync(userContext.UserId, cancellationToken);
        if (existing is not null)
        {
            return existing;
        }

        var profile = ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        return await users.UpsertAsync(profile, cancellationToken);
    }
}

internal static class ProfileDefaults
{
    public const string DefaultTrackId = "az-900";

    public static UserProfileDto New(string userId, string displayName)
    {
        var handle = Handle(displayName, userId);
        return new UserProfileDto(
            Id: userId,
            DisplayName: string.IsNullOrWhiteSpace(displayName) ? "Learner" : displayName,
            Handle: handle,
            AvatarUrl: null,
            Xp: 0,
            Level: 1,
            StreakDays: 0,
            FreezeTokens: 2,
            DailyGoalXp: 50,
            DailyXpEarned: 0,
            Gems: 0,
            ActiveTrackId: DefaultTrackId,
            LastActiveDate: null,
            DailyXpDate: null);
    }

    private static string Handle(string displayName, string userId)
    {
        var basis = string.IsNullOrWhiteSpace(displayName) ? userId : displayName;
        var slug = new string(basis.ToLowerInvariant().Where(char.IsLetterOrDigit).Take(12).ToArray());
        if (slug.Length < 3)
        {
            slug = "learner" + new string(userId.Where(char.IsLetterOrDigit).Take(6).ToArray());
        }

        return slug;
    }
}

public interface IContentService
{
    Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default);
}

public sealed class ContentService(IContentRepository content) : IContentService
{
    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => content.GetLessonAsync(trackId, lessonId, cancellationToken);
}

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

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var scorePct = itemResults.Count == 0 ? 0 : (int)Math.Round(100d * correctCount / itemResults.Count);
        var perfect = itemResults.Count > 0 && correctCount == itemResults.Count;
        var gemsEarned = correctCount + (perfect ? 5 : 0);

        var today = DateOnly.FromDateTime(now.UtcDateTime);
        var sameDay = profile.DailyXpDate == today;
        var newDailyXp = (sameDay ? profile.DailyXpEarned : 0) + xpEarned;
        var goalMet = profile.DailyGoalXp > 0 && newDailyXp >= profile.DailyGoalXp;

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
        var unlockedIds = newlyUnlocked.Select(t => t.Id).ToList();
        var allAchievements = newlyUnlocked.Count == 0
            ? profile.Achievements
            : alreadyUnlocked.Concat(unlockedIds).ToList();

        var updatedProfile = profile with
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
            Gems = gemsBeforeAchievements + achievementGems
        };
        await users.UpsertAsync(updatedProfile, cancellationToken);
        await progress.UpsertMasteryBatchAsync(userContext.UserId, updatedMasteries.Values.ToArray(), cancellationToken);

        // Continuous learning: fold every answered item into the per-user learner
        // model so the AI tutor's personalisation sharpens with each practice
        // session. Idempotent overall — a replayed attempt short-circuits above.
        await RecordLearnerObservationsAsync(request, itemById, now, cancellationToken);

        if (xpEarned > 0)
        {
            await leaderboard.AddXpAsync(userContext.UserId, xpEarned, cancellationToken);
        }

        var result = new SubmitQuizResult(
            Guid.NewGuid().ToString("n"),
            scorePct,
            itemResults,
            new RewardsDto(xpEarned, newXp, newLevel > profile.Level, streakExtended, gemsEarned, unlockedIds),
            updatedMasteries.Values.Where(m => m.MasteryScore < 0.5).Select(m => m.ConceptId).Distinct().ToList(),
            updatedMasteries.Values.OrderBy(m => m.DueAt).Select(m => (DateTimeOffset?)m.DueAt).FirstOrDefault());

        var attempt = new AttemptRecord(result.AttemptId, userContext.UserId, request.ClientAttemptId, request.TrackId, lessonId, request.StartedAt, now, result);
        await attempts.CreateAsync(attempt, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "quiz.submitted", now, result), cancellationToken);

        if (newlyUnlocked.Count > 0)
        {
            await events.AddAsync(new LearningEvent(
                Guid.NewGuid().ToString("n"),
                userContext.UserId,
                "achievement.unlocked",
                now,
                unlockedIds), cancellationToken);
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

public interface ILeaderboardService
{
    Task<LeagueDto> GetMyLeagueAsync(CancellationToken cancellationToken = default);
}

public sealed class LeaderboardService(IUserContext userContext, ILeaderboardRepository leaderboard) : ILeaderboardService
{
    public Task<LeagueDto> GetMyLeagueAsync(CancellationToken cancellationToken = default)
        => leaderboard.GetLeagueAsync(userContext.UserId, cancellationToken);
}

public interface IShopService
{
    Task<ShopCatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default);
    Task<PurchaseResultDto> PurchaseAsync(PurchaseRequest request, CancellationToken cancellationToken = default);
}

public sealed class ShopService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IPurchaseRepository purchases,
    IEventRepository events) : IShopService
{
    public async Task<ShopCatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken);
        var items = ShopCatalog.Items
            .Select(i => new ShopItemDto(i.Id, i.Name, i.Description, i.PriceGems, i.Kind.ToString(), i.Amount))
            .ToArray();
        return new ShopCatalogDto(profile?.Gems ?? 0, items);
    }

    public async Task<PurchaseResultDto> PurchaseAsync(PurchaseRequest request, CancellationToken cancellationToken = default)
    {
        // Only successful (side-effecting) purchases are recorded, so this guard
        // prevents double-charging an idempotent retry without blocking re-tries
        // of a previously failed purchase.
        var prior = await purchases.GetByClientPurchaseIdAsync(userContext.UserId, request.ClientPurchaseId, cancellationToken);
        if (prior is not null)
        {
            return prior.Result;
        }

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var item = ShopCatalog.Find(request.ItemId);
        if (item is null)
        {
            return new PurchaseResultDto(false, request.ItemId, 0, profile.Gems, profile.FreezeTokens, "unknownItem");
        }

        var evaluation = ShopEngine.Evaluate(new PurchaseState(profile.Gems, profile.FreezeTokens), item);
        if (!evaluation.Success)
        {
            return new PurchaseResultDto(false, item.Id, 0, profile.Gems, profile.FreezeTokens, ErrorCode(evaluation.Error));
        }

        var updated = profile with
        {
            Gems = evaluation.State.Gems,
            FreezeTokens = evaluation.State.FreezeTokens,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var result = new PurchaseResultDto(true, item.Id, evaluation.GemsSpent, updated.Gems, updated.FreezeTokens, null);
        var now = clock.UtcNow;
        var record = new PurchaseRecord(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            request.ClientPurchaseId,
            item.Id,
            evaluation.GemsSpent,
            now,
            result);
        await purchases.CreateAsync(record, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "shop.purchased", now, result), cancellationToken);

        return result;
    }

    private static string ErrorCode(PurchaseError error) => error switch
    {
        PurchaseError.InsufficientGems => "insufficientGems",
        PurchaseError.AlreadyAtMax => "alreadyAtMax",
        PurchaseError.UnknownItem => "unknownItem",
        _ => "unknown",
    };
}

public interface IQuestService
{
    Task<QuestBoardDto> GetTodayAsync(CancellationToken cancellationToken = default);
    Task<ClaimQuestResultDto> ClaimAsync(ClaimQuestRequest request, CancellationToken cancellationToken = default);
}

public sealed class QuestService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IEventRepository events) : IQuestService
{
    public async Task<QuestBoardDto> GetTodayAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var (signals, claims) = DailyState(profile, today);

        var quests = QuestEngine.DailyQuests(today, userContext.UserId)
            .Select(t => ToDto(t, signals, claims))
            .ToArray();

        return new QuestBoardDto(today, profile.Gems, quests);
    }

    public async Task<ClaimQuestResultDto> ClaimAsync(ClaimQuestRequest request, CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var (signals, claims) = DailyState(profile, today);

        var template = QuestEngine.DailyQuests(today, userContext.UserId).FirstOrDefault(t => t.Id == request.QuestId);
        if (template is null)
        {
            return new ClaimQuestResultDto(false, request.QuestId, 0, profile.Gems, false, "unknownQuest");
        }

        // Already claimed today: idempotent no-op so a retried claim never
        // double-awards gems.
        if (claims.Contains(template.Id))
        {
            return new ClaimQuestResultDto(true, template.Id, 0, profile.Gems, true, null);
        }

        var status = QuestEngine.Evaluate(template, signals);
        if (!status.Completed)
        {
            return new ClaimQuestResultDto(false, template.Id, 0, profile.Gems, false, "notCompleted");
        }

        var updatedClaims = new List<string>(claims) { template.Id };
        var updated = profile with
        {
            Gems = profile.Gems + template.RewardGems,
            DailyXpDate = today,
            DailyQuestClaims = updatedClaims,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var result = new ClaimQuestResultDto(true, template.Id, template.RewardGems, updated.Gems, true, null);
        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "quest.claimed",
            clock.UtcNow,
            result), cancellationToken);

        return result;
    }

    // Daily counters reset at the day boundary. When the profile's recorded day
    // is not today the learner has no activity yet, so signals and claims are
    // empty (stale values from a previous day are ignored).
    private static (DailySignals Signals, IReadOnlyList<string> Claims) DailyState(UserProfileDto profile, DateOnly today)
    {
        if (profile.DailyXpDate != today)
        {
            return (DailySignals.Empty, Array.Empty<string>());
        }

        var signals = new DailySignals(
            profile.DailyXpEarned,
            profile.DailyLessonsCompleted,
            profile.DailyCorrectAnswers,
            profile.DailyPerfectLessons);
        return (signals, profile.DailyQuestClaims ?? new List<string>());
    }

    private static QuestDto ToDto(QuestTemplate template, DailySignals signals, IReadOnlyList<string> claims)
    {
        var status = QuestEngine.Evaluate(template, signals);
        var claimed = claims.Contains(template.Id);
        return new QuestDto(
            template.Id,
            template.Kind.ToString(),
            template.Title,
            template.Target,
            status.Current,
            template.RewardGems,
            status.Completed,
            claimed,
            status.Completed && !claimed);
    }
}

internal static class AchievementSnapshots
{
    public static AchievementSnapshot From(UserProfileDto p)
        => new(p.StreakDays, p.Xp, p.Level, p.LifetimeLessonsCompleted, p.LifetimePerfectLessons, p.Gems);
}

public interface IAchievementService
{
    Task<AchievementBoardDto> GetAllAsync(CancellationToken cancellationToken = default);
}

public sealed class AchievementService(IUserContext userContext, IUserRepository users) : IAchievementService
{
    public async Task<AchievementBoardDto> GetAllAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var snapshot = AchievementSnapshots.From(profile);
        var unlocked = new HashSet<string>(profile.Achievements ?? new List<string>(), StringComparer.OrdinalIgnoreCase);

        var dtos = AchievementEngine.Tiers.Select(t =>
        {
            var value = snapshot.ValueFor(t.Kind);
            // Treat a tier as unlocked if it was persisted OR the threshold is now
            // met (so the board is correct even before the next quiz persists it).
            var isUnlocked = unlocked.Contains(t.Id) || value >= t.Threshold;
            return new AchievementDto(
                t.Id,
                t.Kind.ToString(),
                t.Name,
                t.Description,
                t.Tier,
                t.Threshold,
                Math.Min(value, t.Threshold),
                t.RewardGems,
                isUnlocked);
        }).ToArray();

        return new AchievementBoardDto(dtos.Count(d => d.Unlocked), dtos.Length, dtos);
    }
}

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

public interface IShareCardService
{
    Task<ShareCardDto> GetDailyAsync(CancellationToken cancellationToken = default);
}

// Builds the server-authoritative payload for the 2-tap daily score share
// (plan §3.10): the numbers a client renders into a story card, plus a stable
// referral code and per-day share id for deep links and K-factor tracking.
public sealed class ShareCardService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IPathService path) : IShareCardService
{
    public async Task<ShareCardDto> GetDailyAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var dailyXp = profile.DailyXpDate == today ? profile.DailyXpEarned : 0;
        var goalMet = profile.DailyGoalXp > 0 && dailyXp >= profile.DailyGoalXp;

        var trackId = string.IsNullOrWhiteSpace(profile.ActiveTrackId)
            ? ProfileDefaults.DefaultTrackId
            : profile.ActiveTrackId!;
        var pathDto = await path.GetPathAsync(trackId, cancellationToken);

        var referral = ShareCodec.ReferralCode(profile.Id);
        var shareId = ShareCodec.DailyShareId(profile.Id, today);
        var mascot = goalMet && profile.StreakDays > 0 ? "Nimbus" : "Pip";
        var headline = profile.StreakDays > 0
            ? $"{profile.StreakDays} jours de série 🔥"
            : "Ma préparation a commencé";
        var caption =
            $"J'en suis à {pathDto.ReadinessScore}% de préparation {pathDto.Exam} sur Microlingo ! "
            + $"Rejoins-moi avec le code {referral} 🚀";

        return new ShareCardDto(
            shareId,
            profile.DisplayName,
            profile.Handle,
            profile.StreakDays,
            profile.Level,
            dailyXp,
            profile.DailyGoalXp,
            goalMet,
            pathDto.ReadinessScore,
            pathDto.Exam,
            mascot,
            headline,
            caption,
            referral,
            clock.UtcNow);
    }
}

public interface IFriendService
{
    Task<FriendListDto> ListAsync(CancellationToken cancellationToken = default);
    Task<FriendActionResultDto> AddByHandleAsync(string handle, CancellationToken cancellationToken = default);
    Task<FriendActionResultDto> RemoveAsync(string friendUserId, CancellationToken cancellationToken = default);
    Task<FriendLeaderboardDto> LeaderboardAsync(CancellationToken cancellationToken = default);
}

// Social graph + friend leaderboard (plan §3.8) — the core virality loop.
// Friendships are mutual: adding writes both directed edges so each side can
// list from its own partition. Adds are idempotent.
public sealed class FriendService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IFriendRepository friends,
    IEventRepository events) : IFriendService
{
    public async Task<FriendListDto> ListAsync(CancellationToken cancellationToken = default)
    {
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        return await BuildListAsync(edges, cancellationToken);
    }

    public async Task<FriendActionResultDto> AddByHandleAsync(string handle, CancellationToken cancellationToken = default)
    {
        var normalized = (handle ?? string.Empty).Trim().TrimStart('@').ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return await FailAsync("invalid_handle", cancellationToken);
        }

        var target = await users.FindByHandleAsync(normalized, cancellationToken);
        if (target is null)
        {
            return await FailAsync("not_found", cancellationToken);
        }

        if (string.Equals(target.Id, userContext.UserId, StringComparison.Ordinal))
        {
            return await FailAsync("self", cancellationToken);
        }

        var now = clock.UtcNow;
        var existing = await friends.GetAsync(userContext.UserId, target.Id, cancellationToken);
        if (existing is null)
        {
            await friends.UpsertAsync(new FriendEdge($"{userContext.UserId}:{target.Id}", userContext.UserId, target.Id, now), cancellationToken);
            await friends.UpsertAsync(new FriendEdge($"{target.Id}:{userContext.UserId}", target.Id, userContext.UserId, now), cancellationToken);
            await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "friend.added", now, new { friendUserId = target.Id }), cancellationToken);
        }

        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        var list = await BuildListAsync(edges, cancellationToken);
        return new FriendActionResultDto(true, target.Id, null, list);
    }

    public async Task<FriendActionResultDto> RemoveAsync(string friendUserId, CancellationToken cancellationToken = default)
    {
        await friends.RemoveAsync(userContext.UserId, friendUserId, cancellationToken);
        await friends.RemoveAsync(friendUserId, userContext.UserId, cancellationToken);
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        var list = await BuildListAsync(edges, cancellationToken);
        return new FriendActionResultDto(true, friendUserId, null, list);
    }

    public async Task<FriendLeaderboardDto> LeaderboardAsync(CancellationToken cancellationToken = default)
    {
        var me = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);

        var profiles = new List<UserProfileDto> { me };
        foreach (var edge in edges)
        {
            var friend = await users.GetAsync(edge.FriendUserId, cancellationToken);
            if (friend is not null)
            {
                profiles.Add(friend);
            }
        }

        var entries = profiles
            .GroupBy(p => p.Id, StringComparer.Ordinal)
            .Select(g => g.First())
            .OrderByDescending(p => p.Xp)
            .ThenBy(p => p.DisplayName, StringComparer.OrdinalIgnoreCase)
            .Select((p, i) => new LeaderboardEntryDto(p.Id, p.DisplayName, p.AvatarUrl, i + 1, p.Xp))
            .ToArray();

        return new FriendLeaderboardDto(userContext.UserId, entries);
    }

    private async Task<FriendListDto> BuildListAsync(IReadOnlyList<FriendEdge> edges, CancellationToken cancellationToken)
    {
        var result = new List<FriendDto>();
        foreach (var edge in edges.OrderBy(e => e.CreatedAt))
        {
            var profile = await users.GetAsync(edge.FriendUserId, cancellationToken);
            if (profile is null)
            {
                continue;
            }

            result.Add(new FriendDto(
                profile.Id,
                profile.DisplayName,
                profile.Handle,
                profile.AvatarUrl,
                profile.Level,
                profile.StreakDays,
                profile.Xp,
                edge.CreatedAt));
        }

        return new FriendListDto(result.Count, result);
    }

    private async Task<FriendActionResultDto> FailAsync(string error, CancellationToken cancellationToken)
    {
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        var list = await BuildListAsync(edges, cancellationToken);
        return new FriendActionResultDto(false, null, error, list);
    }
}

public interface IStreakRepairService
{
    Task<StreakStatusDto> GetStatusAsync(CancellationToken cancellationToken = default);
    Task<StreakRepairResultDto> RepairAsync(StreakRepairRequest request, CancellationToken cancellationToken = default);
}

public sealed class StreakRepairService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IPurchaseRepository purchases,
    IEventRepository events) : IStreakRepairService
{
    public async Task<StreakStatusDto> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var assessment = StreakRepairPolicy.Assess(profile.StreakDays, profile.LastActiveDate, today);
        return new StreakStatusDto(
            profile.StreakDays,
            profile.LastActiveDate,
            profile.FreezeTokens,
            assessment.Repairable,
            assessment.CostGems,
            assessment.Reason);
    }

    public async Task<StreakRepairResultDto> RepairAsync(StreakRepairRequest request, CancellationToken cancellationToken = default)
    {
        // Reuse the purchase ledger for idempotency so a double-tap repairs and
        // charges exactly once (mirrors ShopService.PurchaseAsync).
        var prior = await purchases.GetByClientPurchaseIdAsync(userContext.UserId, request.ClientRepairId, cancellationToken);
        if (prior is not null)
        {
            var existing = await users.GetAsync(userContext.UserId, cancellationToken);
            return new StreakRepairResultDto(
                true,
                existing?.StreakDays ?? 0,
                prior.GemsSpent,
                prior.Result.GemsBalance,
                existing?.LastActiveDate,
                null);
        }

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var assessment = StreakRepairPolicy.Assess(profile.StreakDays, profile.LastActiveDate, today);

        if (!assessment.Repairable)
        {
            return new StreakRepairResultDto(false, profile.StreakDays, 0, profile.Gems, profile.LastActiveDate, assessment.Reason);
        }

        if (profile.Gems < assessment.CostGems)
        {
            return new StreakRepairResultDto(false, profile.StreakDays, 0, profile.Gems, profile.LastActiveDate, "insufficientGems");
        }

        var updated = profile with
        {
            Gems = profile.Gems - assessment.CostGems,
            LastActiveDate = assessment.BridgeTo,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var now = clock.UtcNow;
        var result = new StreakRepairResultDto(true, updated.StreakDays, assessment.CostGems, updated.Gems, updated.LastActiveDate, null);
        var record = new PurchaseRecord(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            request.ClientRepairId,
            "streak-repair",
            assessment.CostGems,
            now,
            new PurchaseResultDto(true, "streak-repair", assessment.CostGems, updated.Gems, updated.FreezeTokens, null));
        await purchases.CreateAsync(record, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "streak.repaired", now, result), cancellationToken);

        return result;
    }
}

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

        var attempt = new ExamAttemptRecord(
            attemptId, userContext.UserId, request.ClientAttemptId, request.TrackId, request.ExamId,
            request.StartedAt, now, result);
        await examAttempts.CreateAsync(attempt, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "exam.submitted", now, result), cancellationToken);

        return result;
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

public interface ITutorService
{
    Task<TutorExplanationDto> ExplainAsync(TutorExplainRequest request, CancellationToken cancellationToken = default);
}

/// The premium AI tutor — a continuously learning agent. It grounds every
/// explanation in the official lesson + answer key, personalises it from the
/// learner's own history (recurring struggles, signature misconceptions, comeback
/// wins), optionally upgrades the prose via a guardrailed LLM, then *learns* from
/// the interaction by folding it back into the per-user model. Works for free and
/// offline (grounded composer) when no LLM provider is configured.
public sealed class TutorService(
    IUserContext userContext,
    IClock clock,
    IContentRepository content,
    ILearnerModelRepository learnerModels,
    ITutorCompletion completion,
    IEventRepository events) : ITutorService
{
    public async Task<TutorExplanationDto> ExplainAsync(TutorExplainRequest request, CancellationToken cancellationToken = default)
    {
        var track = await content.GetTrackAsync(request.TrackId, cancellationToken)
            ?? throw new InvalidOperationException($"Track '{request.TrackId}' was not found.");
        var lesson = await content.GetLessonAsync(request.TrackId, request.LessonId, cancellationToken)
            ?? throw new InvalidOperationException($"Lesson '{request.LessonId}' was not found.");
        var answerKey = await content.GetAnswerKeyAsync(request.TrackId, request.LessonId, cancellationToken)
            ?? throw new InvalidOperationException($"Answer key for lesson '{request.LessonId}' was not found.");

        var keyItem = answerKey.Items.FirstOrDefault(i =>
            string.Equals(i.ItemId, request.ItemId, StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException($"Item '{request.ItemId}' was not found in lesson '{request.LessonId}'.");

        var now = clock.UtcNow;
        var selected = request.Selected ?? new List<string>();

        // Personalise on the learner's history BEFORE this answer.
        var record = await learnerModels.GetAsync(userContext.UserId, request.TrackId, cancellationToken);
        var map = LearnerModelMap.ToMap(record);
        map.TryGetValue(keyItem.ConceptId, out var priorStat);

        var ctx = TutorContextFactory.Create(track, lesson, keyItem, selected, priorStat);
        var grounded = TutorComposer.Compose(ctx);
        var explanation = await UpgradeAsync(ctx, grounded, cancellationToken);

        // Learn from this interaction so the next explanation is more personal.
        var chosenWrong = ctx.IsCorrect ? null : selected.FirstOrDefault();
        map[keyItem.ConceptId] = LearnerModel.Observe(priorStat, keyItem.ConceptId, ctx.IsCorrect, chosenWrong, now);
        await learnerModels.UpsertAsync(
            LearnerModelMap.ToRecord(userContext.UserId, request.TrackId, map, now), cancellationToken);

        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "tutor.explained",
            now,
            new TutorEventPayload(request.TrackId, request.LessonId, keyItem.ItemId, keyItem.ConceptId, ctx.IsCorrect, explanation.Source)),
            cancellationToken);

        return ToDto(ctx, explanation);
    }

    // Attempts an LLM upgrade, but only adopts it if it survives the guardrails
    // (grounding, length, exam-integrity). Any failure, empty reply, malformed
    // JSON, or guardrail violation falls back to the grounded explanation, which
    // is always safe. The recommendation stays grounded regardless of source.
    private async Task<TutorExplanation> UpgradeAsync(
        TutorContext ctx,
        TutorExplanation grounded,
        CancellationToken cancellationToken)
    {
        string? raw;
        try
        {
            raw = await completion.CompleteAsync(
                TutorPromptBuilder.System(), TutorPromptBuilder.User(ctx), cancellationToken);
        }
        catch
        {
            return grounded;
        }

        if (string.IsNullOrWhiteSpace(raw))
        {
            return grounded;
        }

        var candidate = TutorPayloadParser.TryParse(raw!, grounded.Recommendation);
        if (candidate is null)
        {
            return grounded;
        }

        var verdict = TutorGuardrails.Validate(candidate, ctx);
        return verdict.Ok ? candidate : grounded;
    }

    private static TutorExplanationDto ToDto(TutorContext ctx, TutorExplanation e)
    {
        var learner = ctx.Learner;
        var personalization = new TutorPersonalizationDto(
            learner.Attempts,
            learner.Errors,
            (int)Math.Round(learner.Accuracy * 100),
            learner.RecurringStruggle,
            learner.MasteredBefore,
            learner.Trend.ToString().ToLowerInvariant(),
            learner.TopConfusedOptionLabel);

        return new TutorExplanationDto(
            ctx.ItemId,
            ctx.ConceptId,
            ctx.IsCorrect,
            e.Headline,
            e.Points,
            e.Encouragement,
            e.Recommendation,
            e.CitedConceptIds,
            e.Source,
            personalization);
    }
}

internal sealed record TutorEventPayload(
    string TrackId,
    string LessonId,
    string ItemId,
    string ConceptId,
    bool Correct,
    string Source);

/// Parses an LLM reply into a tutor explanation. Tolerant of prose around the
/// JSON object (extracts the outermost braces); returns null on anything it can't
/// confidently read, so the caller falls back to the grounded explanation. The
/// recommendation is always taken from the grounded composer, never the model.
internal static class TutorPayloadParser
{
    public static TutorExplanation? TryParse(string raw, string groundedRecommendation)
    {
        var json = ExtractJsonObject(raw);
        if (json is null)
        {
            return null;
        }

        try
        {
            using var document = JsonDocument.Parse(json);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object)
            {
                return null;
            }

            var headline = GetString(root, "headline");
            var encouragement = GetString(root, "encouragement") ?? string.Empty;
            var points = GetStringArray(root, "points");
            var cited = GetStringArray(root, "citedConceptIds");

            if (string.IsNullOrWhiteSpace(headline) || points.Count == 0)
            {
                return null;
            }

            return new TutorExplanation(headline!, points, encouragement, cited, groundedRecommendation, "ai");
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static string? ExtractJsonObject(string raw)
    {
        var start = raw.IndexOf('{');
        var end = raw.LastIndexOf('}');
        if (start < 0 || end <= start)
        {
            return null;
        }

        return raw.Substring(start, end - start + 1);
    }

    private static string? GetString(JsonElement root, string name)
        => root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static IReadOnlyList<string> GetStringArray(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<string>();
        }

        var list = new List<string>();
        foreach (var element in value.EnumerateArray())
        {
            if (element.ValueKind == JsonValueKind.String)
            {
                var text = element.GetString();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    list.Add(text!);
                }
            }
        }

        return list;
    }
}
