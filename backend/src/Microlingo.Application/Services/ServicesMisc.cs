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
