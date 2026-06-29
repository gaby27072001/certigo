using FluentAssertions;
using Certigo.Domain.Content;
using Certigo.Domain.Exam;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class MockExamTests
{
    private static readonly IReadOnlyList<(string, string, double)> AzDomains = new[]
    {
        ("d1", "Cloud concepts", 0.30),
        ("d2", "Architecture & services", 0.40),
        ("d3", "Governance & management", 0.30)
    };

    // --- Apportionment -------------------------------------------------------

    [Fact]
    public void Apportion_sums_exactly_to_total()
    {
        var allocation = MockExamBlueprint.Apportion(AzDomains, 20);

        allocation.Sum(d => d.ItemCount).Should().Be(20);
    }

    [Fact]
    public void Apportion_is_roughly_proportional_to_weight()
    {
        var allocation = MockExamBlueprint.Apportion(AzDomains, 100);

        allocation.Single(d => d.DomainId == "d1").ItemCount.Should().Be(30);
        allocation.Single(d => d.DomainId == "d2").ItemCount.Should().Be(40);
        allocation.Single(d => d.DomainId == "d3").ItemCount.Should().Be(30);
    }

    [Fact]
    public void Apportion_gives_every_domain_at_least_one_when_length_allows()
    {
        var domains = new[]
        {
            ("big", "Big", 0.95),
            ("tiny", "Tiny", 0.05)
        };

        var allocation = MockExamBlueprint.Apportion(domains, 10);

        allocation.Should().OnlyContain(d => d.ItemCount >= 1);
        allocation.Sum(d => d.ItemCount).Should().Be(10);
    }

    [Fact]
    public void Apportion_returns_empty_for_no_domains_or_zero_length()
    {
        MockExamBlueprint.Apportion(Array.Empty<(string, string, double)>(), 10).Should().BeEmpty();
        MockExamBlueprint.Apportion(AzDomains, 0).Should().BeEmpty();
    }

    // --- Composition ---------------------------------------------------------

    private static IReadOnlyList<ExamItemRef> Pool()
        => new[]
        {
            new ExamItemRef("d1-i1", "l1", "d1", "c1", ItemType.Mcq, 1),
            new ExamItemRef("d1-i2", "l1", "d1", "c2", ItemType.Mcq, 2),
            new ExamItemRef("d1-i3", "l2", "d1", "c3", ItemType.Mcq, 3),
            new ExamItemRef("d2-i1", "l3", "d2", "c4", ItemType.Mcq, 1),
            new ExamItemRef("d2-i2", "l3", "d2", "c5", ItemType.Mcq, 2),
            new ExamItemRef("d3-i1", "l4", "d3", "c6", ItemType.Mcq, 1)
        };

    [Fact]
    public void Compose_respects_per_domain_allocation()
    {
        var allocation = new[]
        {
            new ExamBlueprintDomain("d1", "D1", 0.5, 2),
            new ExamBlueprintDomain("d2", "D2", 0.3, 1),
            new ExamBlueprintDomain("d3", "D3", 0.2, 1)
        };

        var exam = MockExamComposer.Compose(Pool(), allocation, masteryByConcept: null, seed: 1);

        exam.Should().HaveCount(4);
        exam.Count(i => i.DomainId == "d1").Should().Be(2);
        exam.Count(i => i.DomainId == "d2").Should().Be(1);
        exam.Count(i => i.DomainId == "d3").Should().Be(1);
    }

    [Fact]
    public void Compose_prioritises_weak_concepts()
    {
        var allocation = new[] { new ExamBlueprintDomain("d1", "D1", 1.0, 1) };
        var mastery = new Dictionary<string, double>
        {
            ["c1"] = 0.95, // strong → deprioritised
            ["c2"] = 0.10, // weak → should be picked
            ["c3"] = 0.90
        };

        var exam = MockExamComposer.Compose(Pool(), allocation, mastery, seed: 7);

        exam.Should().ContainSingle().Which.ConceptId.Should().Be("c2");
    }

    [Fact]
    public void Compose_is_deterministic_for_a_given_seed()
    {
        var allocation = MockExamBlueprint.Apportion(AzDomains, 4);

        var first = MockExamComposer.Compose(Pool(), allocation, null, seed: 42).Select(i => i.ItemId);
        var second = MockExamComposer.Compose(Pool(), allocation, null, seed: 42).Select(i => i.ItemId);

        first.Should().Equal(second);
    }

    [Fact]
    public void Compose_backfills_when_a_domain_is_short()
    {
        // d3 is allocated 3 but only has 1 candidate; the composer backfills from
        // the rest of the pool so the exam still reaches its target length.
        var allocation = new[]
        {
            new ExamBlueprintDomain("d3", "D3", 0.5, 3),
            new ExamBlueprintDomain("d1", "D1", 0.5, 1)
        };

        var exam = MockExamComposer.Compose(Pool(), allocation, null, seed: 3);

        exam.Should().HaveCount(4);
        exam.Select(i => i.ItemId).Should().OnlyHaveUniqueItems();
    }

    // --- Scoring -------------------------------------------------------------

    private static IReadOnlyList<ExamItemRef> Scored()
        => new[]
        {
            new ExamItemRef("d1-i1", "l1", "d1", "c1", ItemType.Mcq, 1),
            new ExamItemRef("d1-i2", "l1", "d1", "c2", ItemType.Mcq, 2),
            new ExamItemRef("d2-i1", "l3", "d2", "c4", ItemType.Mcq, 1),
            new ExamItemRef("d2-i2", "l3", "d2", "c5", ItemType.Mcq, 2)
        };

    private static IReadOnlyDictionary<string, (string, double)> Meta()
        => new Dictionary<string, (string, double)>
        {
            ["d1"] = ("Concepts", 0.5),
            ["d2"] = ("Governance", 0.5)
        };

    [Fact]
    public void Score_all_correct_is_a_perfect_pass()
    {
        var correct = Scored().ToDictionary(i => i.ItemId, _ => true);

        var score = MockExamScorer.Score(Scored(), correct, Meta());

        score.ScaledScore.Should().Be(1000);
        score.Pct.Should().Be(100);
        score.Passed.Should().BeTrue();
        score.Correct.Should().Be(4);
        score.Total.Should().Be(4);
    }

    [Fact]
    public void Score_weights_domains_not_raw_item_counts()
    {
        // 3 of 4 items correct (75% raw), but the miss is isolated to one
        // equally-weighted domain → weighted accuracy 0.5*1.0 + 0.5*0.5 = 0.75.
        var correct = new Dictionary<string, bool>
        {
            ["d1-i1"] = true,
            ["d1-i2"] = true,
            ["d2-i1"] = true,
            ["d2-i2"] = false
        };

        var score = MockExamScorer.Score(Scored(), correct, Meta());

        score.ScaledScore.Should().Be(750);
        score.Passed.Should().BeTrue();
        score.Domains.Should().HaveCount(2);
        score.Domains.Single(d => d.DomainId == "d2").Pct.Should().Be(50);
    }

    [Fact]
    public void Score_below_700_fails()
    {
        var correct = new Dictionary<string, bool>
        {
            ["d1-i1"] = true,
            ["d1-i2"] = false,
            ["d2-i1"] = false,
            ["d2-i2"] = false
        };

        var score = MockExamScorer.Score(Scored(), correct, Meta());

        score.ScaledScore.Should().Be(250);
        score.Passed.Should().BeFalse();
    }

    [Fact]
    public void Score_empty_submission_is_zero()
    {
        var score = MockExamScorer.Score(Scored(), new Dictionary<string, bool>(), Meta());

        score.ScaledScore.Should().Be(0);
        score.Passed.Should().BeFalse();
        score.Total.Should().Be(0);
        score.Domains.Should().BeEmpty();
    }
}
