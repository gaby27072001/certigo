using FluentAssertions;
using Certigo.Domain.Content;
using Certigo.Domain.Gamification;
using Certigo.Domain.Progress;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class XpEngineTests
{
    [Fact]
    public void ForQuizItem_awards_weak_repair_more_than_easy_regrind()
    {
        var weakBefore = ConceptMastery.New("user-1", "ai-900", "ml:classification")
            with { MasteryScore = 0.49, DueAt = DateTimeOffset.UtcNow.AddDays(-1) };
        var weakAfter = weakBefore with { MasteryScore = 0.51 };
        var knownBefore = weakBefore with { MasteryScore = 0.9 };
        var knownAfter = knownBefore with { MasteryScore = 0.91 };

        var repair = XpEngine.ForQuizItem(ItemType.Applied, 3, true, weakBefore, weakAfter);
        var regrind = XpEngine.ForQuizItem(ItemType.Applied, 1, true, knownBefore, knownAfter);

        repair.Should().BeGreaterThan(regrind);
    }

    [Fact]
    public void ForQuizItem_returns_zero_for_incorrect()
    {
        var mastery = ConceptMastery.New("user-1", "az-900", "core:regions");

        XpEngine.ForQuizItem(ItemType.Mcq, 2, false, mastery, mastery).Should().Be(0);
    }
}
