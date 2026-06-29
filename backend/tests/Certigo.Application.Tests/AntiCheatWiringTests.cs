using FluentAssertions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Xunit;

namespace Certigo.Application.Tests;

// Câblage anti-triche en mode SANCTION (§6/§15). On vérifie le contrat de bord :
// un signal `attempt.flagged` typé est émis pour une tentative incohérente, AUCUN
// pour une tentative honnête, et — crucial — un verdict Reject (≥0.8 : horloge falsifiée /
// vitesse bot) SUPPRIME toutes les récompenses (0 XP, pas de leaderboard, profil intact).
public sealed class AntiCheatWiringTests
{
    [Fact]
    public async Task Honest_quiz_emits_no_attempt_flagged_and_awards_rewards()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync(
            "l1", QuizServiceHarness.Request("honest-1", QuizServiceHarness.Answer("l1-i1", "a")));

        h.Events.Events.Should().NotContain(e => e.Type == "attempt.flagged");
        result.Rewards.XpEarned.Should().BeGreaterThan(0);
        h.Leaderboard.Xp[h.UserId].Should().Be(result.Rewards.XpEarned);
    }

    [Fact]
    public async Task Tampered_clock_quiz_emits_attempt_flagged_and_suppresses_rewards()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        // Horloge cliente falsifiée : la tentative prétend avoir commencé APRÈS l'instant
        // de soumission du serveur (12:00) → temps réel négatif → rejet dur de l'anti-triche.
        var tampered = new SubmitQuizRequest(
            "cheat-1",
            TestContent.TrackId,
            new DateTimeOffset(2025, 1, 6, 12, 5, 0, TimeSpan.Zero),
            new List<AnswerDto> { QuizServiceHarness.Answer("l1-i1", "a") });

        var result = await service.SubmitAsync("l1", tampered);

        var flagged = h.Events.Events.Should().ContainSingle(e => e.Type == "attempt.flagged").Subject;
        var signal = flagged.Payload.Should().BeOfType<AttemptIntegritySignal>().Subject;
        signal.Kind.Should().Be("quiz");
        signal.ReferenceId.Should().Be("l1");
        signal.AttemptId.Should().Be(result.AttemptId);
        signal.Decision.Should().Be("Reject");
        signal.Flags.Should().Contain("SubmittedBeforeStarted");

        // Mode sanction : verdict Reject → récompenses supprimées, profil et leaderboard intacts.
        result.Rewards.XpEarned.Should().Be(0);
        h.Leaderboard.Xp.ContainsKey(h.UserId).Should().BeFalse();
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(0);
    }

    [Fact]
    public async Task Honest_exam_emits_no_attempt_flagged_and_awards_rewards()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync(ExamServiceHarness.Submit(
            "honest-exam", "exam-1",
            ExamServiceHarness.Answer("l1-i1", "a"),
            ExamServiceHarness.Answer("l2-i1", "a"),
            ExamServiceHarness.Answer("l3-i1", "a")));

        h.Events.Events.Should().NotContain(e => e.Type == "attempt.flagged");
        result.Rewards.XpEarned.Should().BeGreaterThan(0);
        h.Leaderboard.Xp[h.UserId].Should().Be(result.Rewards.XpEarned);
    }

    [Fact]
    public async Task Bot_speed_exam_emits_attempt_flagged_and_suppresses_rewards()
    {
        var h = new ExamServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        // Bot : trois items répondus sous le plancher humain (20 ms) → vitesse surhumaine.
        var bot = new SubmitMockExamRequest(
            "cheat-exam",
            TestContent.TrackId,
            "exam-1",
            new DateTimeOffset(2025, 1, 6, 11, 59, 0, TimeSpan.Zero),
            new List<AnswerDto>
            {
                new("l1-i1", ItemType.Mcq, new List<string> { "a" }, 20),
                new("l2-i1", ItemType.Mcq, new List<string> { "a" }, 20),
                new("l3-i1", ItemType.Mcq, new List<string> { "a" }, 20),
            });

        var result = await service.SubmitAsync(bot);

        var flagged = h.Events.Events.Should().ContainSingle(e => e.Type == "attempt.flagged").Subject;
        var signal = flagged.Payload.Should().BeOfType<AttemptIntegritySignal>().Subject;
        signal.Kind.Should().Be("exam");
        signal.ReferenceId.Should().Be("exam-1");
        signal.AttemptId.Should().Be(result.AttemptId);
        signal.Decision.Should().Be("Reject");
        signal.Flags.Should().Contain("SuperhumanItemSpeed");

        // Mode sanction : verdict Reject → récompenses supprimées, profil et leaderboard intacts.
        result.Rewards.XpEarned.Should().Be(0);
        h.Leaderboard.Xp.ContainsKey(h.UserId).Should().BeFalse();
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(0);
    }
}
