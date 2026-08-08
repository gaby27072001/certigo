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
    public InMemoryExamRepository Exams { get; } = new();
    public InMemoryAttemptRepository Attempts { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public ExamService Build()
    {
        var content = TestContent.Build();
        var context = new FakeUserContext(UserId, "Tester");
        Exams.Seed(IssuedExam("exam-1", UserId, Clock.UtcNow));
        return new ExamService(
            context,
            Clock,
            content,
            Progress,
            ExamAttempts,
            Exams,
            Attempts,
            Events,
            Users,
            Leaderboard);
    }

    public static SubmitMockExamRequest Submit(string attemptId, string examId, params AnswerDto[] answers)
        => new(attemptId, TestContent.TrackId, examId, new DateTimeOffset(2025, 1, 6, 11, 59, 0, TimeSpan.Zero), answers.ToList());

    public static AnswerDto Answer(string itemId, params string[] selected)
        => new(itemId, ItemType.Mcq, selected.ToList(), 5_000);

    public static ExamRecord IssuedExam(
        string examId,
        string userId,
        DateTimeOffset createdAt,
        IReadOnlyList<string>? itemIds = null,
        int durationSeconds = 300)
        => new(
            $"exam::{examId}",
            userId,
            examId,
            TestContent.TrackId,
            itemIds ?? ["l1-i1", "l2-i1", "l3-i1"],
            createdAt,
            durationSeconds,
            createdAt.AddSeconds(durationSeconds),
            Math.Max(durationSeconds, 1));
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

        var stored = h.Exams.Records.Single(record => record.ExamId == exam.ExamId);
        stored.UserId.Should().Be(h.UserId);
        stored.TrackId.Should().Be(TestContent.TrackId);
        stored.ItemIds.Should().BeEquivalentTo(exam.Items.Select(item => item.ItemId));
        stored.CreatedAt.Should().Be(h.Clock.UtcNow);
        stored.DurationSeconds.Should().Be(exam.TimeLimitSeconds);
        stored.ExpiresAt.Should().Be(
            h.Clock.UtcNow.AddSeconds(exam.TimeLimitSeconds + (5 * 60)));
        stored.Ttl.Should().Be(
            exam.TimeLimitSeconds + (5 * 60) + (int)TimeSpan.FromDays(1).TotalSeconds);
    }

    [Fact]
    public async Task SubmitAsync_rejects_duplicate_item_ids_before_rewards()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var act = () => service.SubmitAsync(ExamServiceHarness.Submit(
            "duplicate-items",
            "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("L1-I1", "a")));

        await act.Should().ThrowAsync<RequestValidationException>()
            .WithMessage("*Duplicate item id*");
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(0);
        profile.Gems.Should().Be(0);
        h.Leaderboard.Xp.Should().NotContainKey(h.UserId);
        h.ExamAttempts.CreateCount.Should().Be(0);
        h.Events.Events.Should().BeEmpty();
    }

    [Fact]
    public async Task SubmitAsync_rejects_an_item_not_issued_for_the_exam()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        h.Exams.Seed(ExamServiceHarness.IssuedExam(
            "exam-1",
            h.UserId,
            h.Clock.UtcNow,
            itemIds: ["l1-i1"]));

        var act = () => service.SubmitAsync(ExamServiceHarness.Submit(
            "unissued-item",
            "exam-1",
            ExamServiceHarness.Answer("l2-i1", "a")));

        await act.Should().ThrowAsync<RequestValidationException>()
            .WithMessage("*not issued*");
        h.ExamAttempts.CreateCount.Should().Be(0);
    }

    [Fact]
    public async Task SubmitAsync_rejects_an_expired_exam()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        h.Exams.Seed(ExamServiceHarness.IssuedExam(
            "expired",
            h.UserId,
            h.Clock.UtcNow.AddMinutes(-10),
            durationSeconds: 60));

        var act = () => service.SubmitAsync(ExamServiceHarness.Submit(
            "expired-attempt",
            "expired",
            ExamServiceHarness.Answer("l1-i1", "a")));

        await act.Should().ThrowAsync<RequestValidationException>()
            .WithMessage("*expired*");
        h.ExamAttempts.CreateCount.Should().Be(0);
    }

    [Fact]
    public async Task SubmitAsync_rejects_an_exam_owned_by_another_user()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        h.Exams.Seed(ExamServiceHarness.IssuedExam(
            "other-user-exam",
            "other-user",
            h.Clock.UtcNow));

        var act = () => service.SubmitAsync(ExamServiceHarness.Submit(
            "foreign-attempt",
            "other-user-exam",
            ExamServiceHarness.Answer("l1-i1", "a")));

        await act.Should().ThrowAsync<RequestValidationException>()
            .WithMessage("*does not belong*");
        h.ExamAttempts.CreateCount.Should().Be(0);
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
    public async Task SubmitAsync_is_single_use_even_with_a_new_client_attempt_id()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        var firstRequest = ExamServiceHarness.Submit(
            "first-client-attempt",
            "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "a"));
        var secondRequest = firstRequest with { ClientAttemptId = "second-client-attempt" };

        var first = await service.SubmitAsync(firstRequest);
        var second = await service.SubmitAsync(secondRequest);

        second.AttemptId.Should().Be(first.AttemptId);
        h.ExamAttempts.CreateCount.Should().Be(1);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(first.Rewards.XpEarned);
        profile.Gems.Should().Be(first.Rewards.GemsEarned);
        h.Leaderboard.Xp[h.UserId].Should().Be(first.Rewards.XpEarned);
    }

    [Fact]
    public async Task SubmitAsync_scores_unanswered_issued_items_as_incorrect()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync(ExamServiceHarness.Submit(
            "partial-answer-set",
            "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a")));

        result.Correct.Should().Be(1);
        result.Total.Should().Be(3);
        result.Passed.Should().BeFalse();
        result.Rewards.GemsEarned.Should().Be(0);
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

    [Fact]
    public async Task SubmitAsync_recovers_the_reward_when_the_profile_write_conflicts_once()
    {
        // Un writer concurrent distinct (ex. un achat boutique) fait muter le profil
        // entre notre lecture et notre écriture : le premier upsert entre en conflit.
        // Le retry de concurrence optimiste doit relire et ré-appliquer, créditant la
        // récompense exactement une fois. Ici l'attempt idempotent est créé AVANT
        // l'upsert : sans retry, l'exception laisserait l'attempt en base mais le profil
        // non crédité → le rejeu client renverrait le résultat caché SANS re-créditer →
        // XP/gems définitivement perdus. C'est le gate obligatoire de R-01.
        var inner = new InMemoryUserRepository();
        inner.Seed(TestContent.NewProfile("user-1"));
        var users = new ConflictOnceUserRepository(inner);
        var clock = new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var examAttempts = new InMemoryExamAttemptRepository();
        var exams = new InMemoryExamRepository();
        exams.Seed(ExamServiceHarness.IssuedExam("exam-1", "user-1", clock.UtcNow));
        var leaderboard = new InMemoryLeaderboardRepository();
        var service = new ExamService(
            new FakeUserContext("user-1", "Tester"),
            clock,
            TestContent.Build(),
            new InMemoryProgressRepository(),
            examAttempts,
            exams,
            new InMemoryAttemptRepository(),
            new InMemoryEventRepository(),
            users,
            leaderboard);

        var result = await service.SubmitAsync(ExamServiceHarness.Submit(
            "a1", "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "a")));

        users.UpsertCalls.Should().BeGreaterThanOrEqualTo(2); // conflit une fois, puis ré-appliqué
        var profile = await inner.GetAsync("user-1");
        profile!.Xp.Should().Be(result.Rewards.XpEarned); // récupéré, pas perdu
        profile.Gems.Should().Be(20); // bonus de passage appliqué exactement une fois
        examAttempts.CreateCount.Should().Be(1); // attempt idempotent créé une seule fois
        leaderboard.Xp["user-1"].Should().Be(result.Rewards.XpEarned);
    }

    [Fact]
    public async Task SubmitAsync_no_lost_update_when_a_distinct_writer_commits_first()
    {
        // Preuve directe d'absence de lost update : un writer DISTINCT crédite +100 XP
        // out-of-band juste avant notre écriture (et fait donc échouer notre premier
        // upsert). Le retry doit relire ce profil frais puis empiler notre gain d'examen
        // dessus → total final = gain externe + gain examen, aucune écriture écrasée.
        var inner = new InMemoryUserRepository();
        inner.Seed(TestContent.NewProfile("user-1"));
        var users = new BumpThenConflictUserRepository(inner, p => p with { Xp = p.Xp + 100 });
        var clock = new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var examAttempts = new InMemoryExamAttemptRepository();
        var exams = new InMemoryExamRepository();
        exams.Seed(ExamServiceHarness.IssuedExam("exam-1", "user-1", clock.UtcNow));
        var leaderboard = new InMemoryLeaderboardRepository();
        var service = new ExamService(
            new FakeUserContext("user-1", "Tester"),
            clock,
            TestContent.Build(),
            new InMemoryProgressRepository(),
            examAttempts,
            exams,
            new InMemoryAttemptRepository(),
            new InMemoryEventRepository(),
            users,
            leaderboard);

        var result = await service.SubmitAsync(ExamServiceHarness.Submit(
            "a1", "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "a")));

        users.UpsertCalls.Should().BeGreaterThanOrEqualTo(2);
        var profile = await inner.GetAsync("user-1");
        profile!.Xp.Should().Be(100 + result.Rewards.XpEarned); // gain externe préservé + notre gain
        profile.Gems.Should().Be(20); // bonus de passage une seule fois
        examAttempts.CreateCount.Should().Be(1);
    }
}
