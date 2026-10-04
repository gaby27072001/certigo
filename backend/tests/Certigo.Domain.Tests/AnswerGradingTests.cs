using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

/// Vectors shared in spirit with answer_grading_test.dart: the server must grade
/// exactly as the client's gradeSelection does (AGENTS.md parity rule).
public sealed class AnswerGradingTests
{
    [Theory]
    [InlineData(ItemType.Ordering)]
    [InlineData(ItemType.Cloze)]
    [InlineData(ItemType.Applied)]
    public void Ordered_types_reject_the_right_ids_in_the_wrong_order(ItemType type)
    {
        AnswerGrading.IsCorrect(type, ["a", "b", "c"], ["a", "b", "c"]).Should().BeTrue();
        AnswerGrading.IsCorrect(type, ["a", "b", "c"], ["c", "b", "a"]).Should().BeFalse();
        AnswerGrading.IsCorrect(type, ["a", "b", "c"], ["a", "b"]).Should().BeFalse();
    }

    [Theory]
    [InlineData(ItemType.Mcq)]
    [InlineData(ItemType.Multi)]
    [InlineData(ItemType.Scenario)]
    [InlineData(ItemType.SpotTheIssue)]
    [InlineData(ItemType.MatchPairs)]
    public void Unordered_types_ignore_selection_order(ItemType type)
    {
        AnswerGrading.IsCorrect(type, ["a", "b"], ["b", "a"]).Should().BeTrue();
        AnswerGrading.IsCorrect(type, ["a", "b"], ["a", "c"]).Should().BeFalse();
        AnswerGrading.IsCorrect(type, ["a", "b"], ["a"]).Should().BeFalse();
    }

    [Fact]
    public void Unordered_types_compare_as_multisets_not_as_sets()
    {
        AnswerGrading.IsCorrect(ItemType.Multi, ["a", "b"], ["a", "a"]).Should().BeFalse();
    }

    [Fact]
    public void Match_pairs_compare_left_right_tokens_as_a_set()
    {
        string[] correct = ["l1:r2", "l2:r1"];

        AnswerGrading.IsCorrect(ItemType.MatchPairs, correct, ["l2:r1", "l1:r2"]).Should().BeTrue();
        AnswerGrading.IsCorrect(ItemType.MatchPairs, correct, ["l1:r1", "l2:r2"]).Should().BeFalse();
    }

    [Fact]
    public void A_missing_selection_is_never_correct()
    {
        AnswerGrading.IsCorrect(ItemType.Mcq, ["a"], null).Should().BeFalse();
        AnswerGrading.IsCorrect(ItemType.Ordering, ["a"], []).Should().BeFalse();
    }

    [Fact]
    public void Ids_compare_case_insensitively_as_before()
    {
        AnswerGrading.IsCorrect(ItemType.Mcq, ["PaaS"], ["paas"]).Should().BeTrue();
        AnswerGrading.IsCorrect(ItemType.Ordering, ["A", "B"], ["a", "b"]).Should().BeTrue();
    }
}
