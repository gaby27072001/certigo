using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Progress;

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

        var profile = new UserProfileDto(userContext.UserId, userContext.DisplayName, 0, 1, 0, 2, 50, 0);
        return await users.UpsertAsync(profile, cancellationToken);
    }
}

public interface IContentService
{
    Task<LessonDto?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default);
}

public sealed class ContentService(IContentRepository content) : IContentService
{
    public async Task<LessonDto?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
    {
        var lesson = await content.GetLessonAsync(trackId, lessonId, cancellationToken);
        if (lesson is null)
        {
            return null;
        }

        var items = await content.GetItemsAsync(trackId, lesson.ItemIds, cancellationToken);
        return new LessonDto(
            lesson.Id,
            lesson.TrackId,
            lesson.UnitId,
            lesson.DomainId,
            lesson.Order,
            lesson.Title,
            lesson.EstMinutes,
            lesson.Blocks,
            items.Select(i => new QuizItemDto(i.Id, i.TrackId, i.ConceptId, i.DomainId, i.ItemType, i.Bloom, i.Difficulty, i.Stem, i.Options)).ToArray());
    }
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
    IUserRepository users) : IQuizService
{
    public async Task<SubmitQuizResult> SubmitAsync(string lessonId, SubmitQuizRequest request, CancellationToken cancellationToken = default)
    {
        var prior = await attempts.GetByClientAttemptIdAsync(userContext.UserId, request.ClientAttemptId, cancellationToken);
        if (prior is not null)
        {
            return prior.Result;
        }

        var lesson = await content.GetLessonAsync(request.TrackId, lessonId, cancellationToken)
            ?? throw new InvalidOperationException($"Lesson '{lessonId}' was not found.");
        var items = await content.GetItemsAsync(request.TrackId, lesson.ItemIds, cancellationToken);
        var itemById = items.ToDictionary(i => i.Id, StringComparer.OrdinalIgnoreCase);
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

            var before = await progress.GetMasteryAsync(userContext.UserId, item.TrackId, item.ConceptId, cancellationToken)
                ?? ConceptMastery.New(userContext.UserId, item.TrackId, item.ConceptId);
            var grade = ReviewScheduler.GradeFrom(correct, answer.LatencyMs);
            var after = ReviewScheduler.Apply(before, grade, now);
            updatedMasteries[item.ConceptId] = after;
            xpEarned += XpEngine.ForQuizItem(item, correct, before, after);

            itemResults.Add(new ItemResultDto(
                item.Id,
                correct,
                item.ConceptId,
                correct ? null : item.Correct.ToList(),
                item.Explanation,
                Math.Round(after.MasteryScore - before.MasteryScore, 4)));
        }

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? new UserProfileDto(userContext.UserId, userContext.DisplayName, 0, 1, 0, 2, 50, 0);
        var newXp = profile.Xp + xpEarned;
        var newLevel = XpEngine.LevelFromXp(newXp);
        var updatedProfile = profile with
        {
            Xp = newXp,
            Level = newLevel,
            DailyXpEarned = profile.DailyXpEarned + xpEarned
        };
        await users.UpsertAsync(updatedProfile, cancellationToken);

        await progress.UpsertMasteryBatchAsync(userContext.UserId, updatedMasteries.Values.ToArray(), cancellationToken);

        var scorePct = itemResults.Count == 0 ? 0 : (int)Math.Round(100d * correctCount / itemResults.Count);
        var result = new SubmitQuizResult(
            Guid.NewGuid().ToString("n"),
            scorePct,
            itemResults,
            new RewardsDto(xpEarned, newXp, newLevel > profile.Level, false, new List<string>()),
            updatedMasteries.Values.Where(m => m.MasteryScore < 0.5).Select(m => m.ConceptId).Distinct().ToList(),
            updatedMasteries.Values.OrderBy(m => m.DueAt).FirstOrDefault()?.DueAt);

        var attempt = new AttemptRecord(result.AttemptId, userContext.UserId, request.ClientAttemptId, request.TrackId, lessonId, request.StartedAt, now, result);
        await attempts.CreateAsync(attempt, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "quiz.submitted", now, result), cancellationToken);

        return result;
    }

    private static bool IsCorrect(QuizItem item, AnswerDto answer)
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

public interface IPathService
{
    Task<PathDto> GetPathAsync(string trackId, CancellationToken cancellationToken = default);
}

public sealed class PathService() : IPathService
{
    public Task<PathDto> GetPathAsync(string trackId, CancellationToken cancellationToken = default)
        => Task.FromResult(new PathDto(trackId, "Adaptive Microsoft certification path", 0, Array.Empty<string>()));
}
