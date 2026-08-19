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

internal static class ProfileDefaults
{
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
            ActiveTrackId: null,
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
