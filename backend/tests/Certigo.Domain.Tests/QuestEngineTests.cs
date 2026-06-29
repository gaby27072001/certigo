using FluentAssertions;
using Certigo.Domain.Gamification;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class QuestEngineTests
{
    private static readonly DateOnly Date = new(2025, 1, 6);

    [Fact]
    public void DailyQuests_returns_three_quests_of_distinct_kinds()
    {
        var quests = QuestEngine.DailyQuests(Date, "user-1");

        quests.Should().HaveCount(3);
        quests.Select(q => q.Kind).Should().OnlyHaveUniqueItems();
        quests.Should().OnlyContain(q => QuestEngine.Pool.Contains(q));
    }

    [Fact]
    public void DailyQuests_is_deterministic_for_same_user_and_date()
    {
        var first = QuestEngine.DailyQuests(Date, "user-1").Select(q => q.Id);
        var second = QuestEngine.DailyQuests(Date, "user-1").Select(q => q.Id);

        second.Should().Equal(first);
    }

    [Fact]
    public void DailyQuests_varies_by_user()
    {
        var a = QuestEngine.DailyQuests(Date, "alice").Select(q => q.Id).ToArray();
        var b = QuestEngine.DailyQuests(Date, "bob-the-very-different").Select(q => q.Id).ToArray();

        // Not a hard guarantee, but these two seeds must not collide on all three.
        a.Should().NotEqual(b);
    }

    [Fact]
    public void Evaluate_marks_completed_and_caps_current_at_target()
    {
        var template = new QuestTemplate("t", QuestKind.EarnXp, "x", 30, 10);

        var done = QuestEngine.Evaluate(template, new DailySignals(45, 0, 0, 0));
        done.Completed.Should().BeTrue();
        done.Current.Should().Be(30);

        var partial = QuestEngine.Evaluate(template, new DailySignals(12, 0, 0, 0));
        partial.Completed.Should().BeFalse();
        partial.Current.Should().Be(12);
    }

    [Theory]
    [InlineData(QuestKind.EarnXp, 7)]
    [InlineData(QuestKind.CompleteLessons, 3)]
    [InlineData(QuestKind.AnswerCorrect, 5)]
    [InlineData(QuestKind.FlawlessLesson, 1)]
    public void Progress_reads_the_matching_signal(QuestKind kind, int expected)
    {
        var signals = new DailySignals(XpEarned: 7, LessonsCompleted: 3, CorrectAnswers: 5, PerfectLessons: 1);

        QuestEngine.Progress(kind, signals).Should().Be(expected);
    }
}
