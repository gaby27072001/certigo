using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class ExamServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryProgressRepository Progress { get; } = new();
    public InMemoryLeaderboardRepository Leaderboard { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public InMemoryExamAttemptRepository ExamAttempts { get; } = new();
    public InMemoryAttemptRepository Attempts { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public ExamService Build()
    {
        var content = TestContent.Build();
        var context = new FakeUserContext(UserId, "Tester");
        return new ExamService(context, Clock, content, Progress, ExamAttempts, Attempts, Events, Users, Leaderboard);
    }

    public static SubmitMockExamRequest Submit(string attemptId, string examId, params AnswerDto[] answers)
        => new(attemptId, TestContent.TrackId, examId, new DateTimeOffset(2025, 1, 6, 11, 59, 0, TimeSpan.Zero), answers.ToList());

    public static AnswerDto Answer(string itemId, params string[] selected)
        => new(itemId, ItemType.Mcq, selected.ToList(), 5_000);
}

public sealed class ExamServiceTests
{
    [Fact]
    public async Task GenerateAsync_builds_an_answer_free_exam_with_blueprint()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var exam = await service.GenerateAsync(new MockExamRequest(TestContent.TrackId));

        exam.TrackCode.Should().Be("AZ-900");
        exam.PassingScore.Should().Be(700);
        exam.Items.Should().HaveCount(3); // pool has exactly 3 gradable items
        exam.Items.Should().OnlyContain(i => !string.IsNullOrWhiteSpace(i.Stem) && i.Options.Count == 2);
        exam.Blueprint.Sum(b => b.ItemCount).Should().Be(3);
        exam.TimeLimitSeconds.Should().Be(3 * 75);
    }

    [Fact]
    public async Task SubmitAsync_all_correct_is_a_perfect_pass_with_rewards()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync(ExamServiceHarness.Submit(
            "a1", "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "a")));

        result.ScaledScore.Should().Be(1000);
        result.Passed.Should().BeTrue();
        result.Correct.Should().Be(3);
        result.Total.Should().Be(3);
        result.Domains.Should().HaveCount(2);
        result.Rewards.XpEarned.Should().BeGreaterThan(0);
        result.Rewards.GemsEarned.Should().Be(20); // flat pass bonus

        h.Leaderboard.Xp[h.UserId].Should().Be(result.Rewards.XpEarned);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(result.Rewards.XpEarned);
        profile.Gems.Should().Be(20);
        h.Events.Events.Should().Contain(e => e.Type == "exam.submitted");
    }

    [Fact]
    public async Task SubmitAsync_is_idempotent_per_client_attempt_id()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        var request = ExamServiceHarness.Submit(
            "dup", "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "a"));

        var first = await service.SubmitAsync(request);
        var second = await service.SubmitAsync(request);

        second.AttemptId.Should().Be(first.AttemptId);
        h.ExamAttempts.CreateCount.Should().Be(1);
    }

    [Fact]
    public async Task SubmitAsync_partial_score_breaks_down_by_domain_and_pays_no_bonus()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        // Both concept-domain items correct, the governance item wrong → weighted
        // accuracy 0.5*1.0 + 0.5*0.0 = 0.5 → scaled 500, a fail.
        var result = await service.SubmitAsync(ExamServiceHarness.Submit(
            "a2", "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "b")));

        result.ScaledScore.Should().Be(500);
        result.Passed.Should().BeFalse();
        result.Rewards.GemsEarned.Should().Be(0);

        result.Domains.Single(d => d.DomainId == "d-governance").Correct.Should().Be(0);
        result.Domains.Single(d => d.DomainId == "d-concepts").Correct.Should().Be(2);
    }

    [Fact]
    public async Task SubmitAsync_flags_submission_spam_via_the_rate_window()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var at = h.Clock.UtcNow;
        // 40 prior attempts in the trailing hour = the per-window cap; the 41st (this exam)
        // trips the AttemptRateExceeded detector, which stayed dormant for exams until the
        // rate window was wired into ExamService. XpEarned=0 on the seeds isolates the count
        // flag. Exam attempts share the attempts container with lessons in production, so the
        // detector treats lesson and exam submissions as one combined cadence budget.
        for (var i = 0; i < 40; i++)
        {
            h.Attempts.Seed(new AttemptRecord(
                $"attempt::seed-{i}", h.UserId, $"seed-{i}", TestContent.TrackId, "l1", at, at,
                new SubmitQuizResult($"r{i}", 100, new List<ItemResultDto>(),
                    new RewardsDto(0, 0, false, false, 0, new List<string>()),
                    new List<string>(), null)));
        }
        var service = h.Build();

        var result = await service.SubmitAsync(ExamServiceHarness.Submit(
            "rate-exam-1", "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "a")));

        var flagged = h.Events.Events.SingleOrDefault(e => e.Type == "attempt.flagged");
        flagged.Should().NotBeNull();
        ((AttemptIntegritySignal)flagged!.Payload).Flags.Should().Contain("AttemptRateExceeded");
        ((AttemptIntegritySignal)flagged.Payload).Decision.Should().Be("Flag");

        // Cadence = signal mou (Flag) : détection sans sanction. Récompenses conservées.
        result.Rewards.XpEarned.Should().BeGreaterThan(0);
        h.Leaderboard.Xp[h.UserId].Should().Be(result.Rewards.XpEarned);
    }
}
