using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Gamification;

namespace Certigo.Application.Services;

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
