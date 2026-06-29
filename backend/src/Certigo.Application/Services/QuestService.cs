using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Gamification;
using Certigo.Domain.Notifications;

namespace Certigo.Application.Services;

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
