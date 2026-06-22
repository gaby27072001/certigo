using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Readiness;

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
    ILeaderboardRepository leaderboard) : IQuizService
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
        var updatedProfile = profile with
        {
            Xp = newXp,
            Level = newLevel,
            StreakDays = goalMet ? newStats.StreakDays : profile.StreakDays,
            FreezeTokens = goalMet ? newStats.FreezeTokens : profile.FreezeTokens,
            LastActiveDate = goalMet ? newStats.LastActiveDate : profile.LastActiveDate,
            DailyXpEarned = newDailyXp,
            DailyXpDate = today,
            Gems = profile.Gems + gemsEarned
        };
        await users.UpsertAsync(updatedProfile, cancellationToken);
        await progress.UpsertMasteryBatchAsync(userContext.UserId, updatedMasteries.Values.ToArray(), cancellationToken);

        if (xpEarned > 0)
        {
            await leaderboard.AddXpAsync(userContext.UserId, xpEarned, cancellationToken);
        }

        var result = new SubmitQuizResult(
            Guid.NewGuid().ToString("n"),
            scorePct,
            itemResults,
            new RewardsDto(xpEarned, newXp, newLevel > profile.Level, streakExtended, gemsEarned, new List<string>()),
            updatedMasteries.Values.Where(m => m.MasteryScore < 0.5).Select(m => m.ConceptId).Distinct().ToList(),
            updatedMasteries.Values.OrderBy(m => m.DueAt).Select(m => (DateTimeOffset?)m.DueAt).FirstOrDefault());

        var attempt = new AttemptRecord(result.AttemptId, userContext.UserId, request.ClientAttemptId, request.TrackId, lessonId, request.StartedAt, now, result);
        await attempts.CreateAsync(attempt, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "quiz.submitted", now, result), cancellationToken);

        return result;
    }

    private static bool IsCorrect(AnswerKeyItem item, AnswerDto answer)
    {
        var expected = item.Correct.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        var actual = answer.Selected.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        return expected.SequenceEqual(actual, StringComparer.OrdinalIgnoreCase);
    }
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
