using FluentAssertions;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;
using Microlingo.Domain.Content;
using Xunit;

namespace Microlingo.Application.Tests;

internal sealed class QuizServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryProgressRepository Progress { get; } = new();
    public InMemoryLeaderboardRepository Leaderboard { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public InMemoryAttemptRepository Attempts { get; } = new();
    public InMemoryLearnerModelRepository LearnerModels { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public QuizService Build()
    {
        var content = TestContent.Build();
        var context = new FakeUserContext(UserId, "Tester");
        return new QuizService(context, Clock, content, Progress, Attempts, Events, Users, Leaderboard, LearnerModels);
    }

    public static SubmitQuizRequest Request(string attemptId, params AnswerDto[] answers)
        => new(attemptId, TestContent.TrackId, new DateTimeOffset(2025, 1, 6, 11, 59, 0, TimeSpan.Zero), answers.ToList());

    public static AnswerDto Answer(string itemId, params string[] selected)
        => new(itemId, ItemType.Mcq, selected.ToList(), 5_000);
}

public sealed class QuizServiceTests
{
    [Fact]
    public async Task SubmitAsync_correct_answer_awards_xp_gems_and_updates_leaderboard()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "a")));

        result.ScorePct.Should().Be(100);
        result.Results.Should().ContainSingle().Which.Correct.Should().BeTrue();
        result.Rewards.XpEarned.Should().BeGreaterThan(0);
        result.Rewards.GemsEarned.Should().Be(6); // 1 correct + 5 perfect bonus

        h.Leaderboard.Xp[h.UserId].Should().Be(result.Rewards.XpEarned);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(result.Rewards.XpEarned);
        profile.Gems.Should().Be(6);
        profile.DailyXpEarned.Should().Be(result.Rewards.XpEarned);

        var stored = await h.Progress.GetMasteryAsync(h.UserId, TestContent.TrackId, "c1");
        stored.Should().NotBeNull();
        stored!.Reps.Should().Be(1);
    }

    [Fact]
    public async Task SubmitAsync_is_idempotent_per_client_attempt_id()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        var request = QuizServiceHarness.Request("dup", QuizServiceHarness.Answer("l1-i1", "a"));

        var first = await service.SubmitAsync("l1", request);
        var second = await service.SubmitAsync("l1", request);

        second.AttemptId.Should().Be(first.AttemptId);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(first.Rewards.XpEarned); // not doubled
        h.Leaderboard.Xp[h.UserId].Should().Be(first.Rewards.XpEarned);
    }

    [Fact]
    public async Task SubmitAsync_extends_streak_when_daily_goal_met()
    {
        var h = new QuizServiceHarness();
        var today = DateOnly.FromDateTime(h.Clock.UtcNow.UtcDateTime);
        h.Users.Seed(TestContent.NewProfile(h.UserId, dailyGoalXp: 1) with
        {
            StreakDays = 3,
            LastActiveDate = today.AddDays(-1)
        });
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "a")));

        result.Rewards.StreakExtended.Should().BeTrue();
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.StreakDays.Should().Be(4);
        profile.LastActiveDate.Should().Be(today);
        profile.DailyXpDate.Should().Be(today);
    }

    [Fact]
    public async Task SubmitAsync_incorrect_answer_reveals_key_and_awards_nothing()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "b")));

        result.ScorePct.Should().Be(0);
        var item = result.Results.Should().ContainSingle().Subject;
        item.Correct.Should().BeFalse();
        item.CorrectAnswer.Should().BeEquivalentTo(new[] { "a" });
        item.Explanation.Should().NotBeNullOrEmpty();
        result.Rewards.XpEarned.Should().Be(0);
        result.Rewards.GemsEarned.Should().Be(0);
        result.Rewards.StreakExtended.Should().BeFalse();
        result.WeakConcepts.Should().Contain("c1");
    }

    [Fact]
    public async Task SubmitAsync_unlocks_achievement_awarding_bonus_gems_on_top_of_lesson_gems()
    {
        var h = new QuizServiceHarness();
        // Four prior flawless lessons: a fifth perfect lesson crosses the
        // "Sans-faute · Bronze" (flawless-5) threshold.
        h.Users.Seed(TestContent.NewProfile(h.UserId) with { LifetimePerfectLessons = 4 });
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "a")));

        result.Rewards.AchievementsUnlocked.Should().ContainSingle().Which.Should().Be("flawless-5");
        result.Rewards.GemsEarned.Should().Be(6); // lesson gems only, excludes the achievement bonus

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Achievements.Should().Contain("flawless-5");
        profile.LifetimePerfectLessons.Should().Be(5);
        profile.LifetimeLessonsCompleted.Should().Be(1);
        profile.Gems.Should().Be(26); // 6 lesson gems + 20 achievement reward
    }
}
