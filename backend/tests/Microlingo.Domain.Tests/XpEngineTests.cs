using FluentAssertions;
using Microlingo.Domain.Content;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Progress;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class XpEngineTests
{
    [Fact]
    public void ForQuizItem_awards_weak_repair_more_than_easy_regrind()
    {
        var item = NewItem(ItemType.Applied, 0.8);
        var weakBefore = ConceptMastery.New("user-1", "ai-900", "ml:classification")
            with { MasteryScore = 0.49, DueAt = DateTimeOffset.UtcNow.AddDays(-1) };
        var weakAfter = weakBefore with { MasteryScore = 0.51 };
        var knownBefore = weakBefore with { MasteryScore = 0.9 };
        var knownAfter = knownBefore with { MasteryScore = 0.91 };

        var repair = XpEngine.ForQuizItem(item, true, weakBefore, weakAfter);
        var regrind = XpEngine.ForQuizItem(item with { Difficulty = 0.2 }, true, knownBefore, knownAfter);

        repair.Should().BeGreaterThan(regrind);
    }

    [Fact]
    public void ForQuizItem_returns_zero_for_incorrect()
    {
        var item = NewItem(ItemType.Mcq, 0.5);
        var mastery = ConceptMastery.New("user-1", "az-900", "core:regions");

        XpEngine.ForQuizItem(item, false, mastery, mastery).Should().Be(0);
    }

    private static QuizItem NewItem(ItemType type, double difficulty) =>
        new("item-1", "az-900", "core:regions", "core", type, "Understand", difficulty, "Stem", [], ["a"], "Because.");
}
