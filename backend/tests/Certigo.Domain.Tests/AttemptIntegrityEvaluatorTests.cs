using FluentAssertions;
using Certigo.Domain.Integrity;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class AttemptIntegrityEvaluatorTests
{
    private static readonly DateTimeOffset Start = new(2025, 1, 6, 12, 0, 0, TimeSpan.Zero);

    private static AttemptTiming Timing(double wallMs, int[] latencies, int xp = 30) =>
        new(Start, Start.AddMilliseconds(wallMs), latencies, xp);

    // --- Le cas qui DOIT rester propre : un apprenant honnête ----------------

    [Fact]
    public void Honest_attempt_is_clean()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }));

        verdict.Should().Be(IntegrityVerdict.Clean);
        verdict.IsClean.Should().BeTrue();
        verdict.Decision.Should().Be(IntegrityDecision.Allow);
        verdict.RiskScore.Should().Be(0d);
        verdict.Flags.Should().BeEmpty();
    }

    [Fact]
    public void One_or_two_item_fast_attempt_is_never_speed_flagged()
    {
        // En deçà du minimum d'items, aucun détecteur de vitesse ne se déclenche :
        // garantit qu'un quiz honnête court (comme les 288 tests existants) passe.
        var twoFastItems = AttemptIntegrityEvaluator.Evaluate(
            Timing(100, new[] { 10, 10 }, xp: 20));

        twoFastItems.IsClean.Should().BeTrue();
        twoFastItems.Flags.Should().BeEmpty();
    }

    // --- Détecteur 1 : cohérence temporelle (dur) ----------------------------

    [Fact]
    public void Submitted_before_started_is_hard_rejected()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            new AttemptTiming(Start, Start.AddMilliseconds(-60_000), new[] { 5000, 5000, 5000 }, 30));

        verdict.Decision.Should().Be(IntegrityDecision.Reject);
        verdict.RiskScore.Should().Be(1d);
        verdict.Flags.Should().Equal(IntegrityFlag.SubmittedBeforeStarted);
    }

    // --- Détecteur 2 : vitesse surhumaine par item ---------------------------

    [Fact]
    public void Superhuman_item_speed_at_threshold_fraction_is_flagged()
    {
        // 3 items sous le plancher sur 5 = fraction 0.6 (pile au seuil) → Flag.
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 50, 50, 50, 5000, 5000 }));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.RiskScore.Should().BeApproximately(0.6, 1e-9);
        verdict.Flags.Should().Equal(IntegrityFlag.SuperhumanItemSpeed);
    }

    [Fact]
    public void Superhuman_item_speed_below_threshold_fraction_is_not_flagged()
    {
        // 2 items sous le plancher sur 5 = fraction 0.4 (< 0.6) → aucun drapeau.
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 50, 50, 5000, 5000, 5000 }));

        verdict.IsClean.Should().BeTrue();
        verdict.Flags.Should().BeEmpty();
    }

    [Fact]
    public void Negative_latencies_are_clamped_to_zero_and_count_as_sub_floor()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { -5, -5, -5 }));

        verdict.Decision.Should().Be(IntegrityDecision.Reject);
        verdict.Flags.Should().Equal(IntegrityFlag.SuperhumanItemSpeed);
    }

    // --- Détecteur 3 : temps réel agrégé trop court --------------------------

    [Fact]
    public void Attempt_too_fast_overall_is_flagged()
    {
        // 6 items, plancher humain agrégé = 6*800*0.5 = 2400 ms ; temps réel 1440 ms.
        // Latences >= plancher pour isoler ce détecteur ; risque = 1 - 1440/2400 = 0.4.
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(1440, new[] { 350, 350, 350, 350, 350, 350 }));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.RiskScore.Should().BeApproximately(0.4, 1e-9);
        verdict.Flags.Should().Equal(IntegrityFlag.AttemptTooFastOverall);
    }

    // --- Détecteur 4 : latences fabriquées (incohérence interne) -------------

    [Fact]
    public void Inconsistent_latencies_partial_overrun_is_flagged()
    {
        // Temps réel 2000 ms (>= plancher agrégé 1200) → pas de drapeau « trop rapide ».
        // Somme des latences 4500 > budget 3000 (1.5×2000) → risque = 1500/3000 = 0.5.
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(2000, new[] { 1500, 1500, 1500 }));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.RiskScore.Should().BeApproximately(0.5, 1e-9);
        verdict.Flags.Should().Equal(IntegrityFlag.InconsistentLatencies);
    }

    [Fact]
    public void Inconsistent_latencies_massive_overrun_is_rejected()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(2000, new[] { 30_000, 30_000, 30_000 }));

        verdict.Decision.Should().Be(IntegrityDecision.Reject);
        verdict.RiskScore.Should().BeApproximately(1d, 1e-9);
        verdict.Flags.Should().Equal(IntegrityFlag.InconsistentLatencies);
    }

    // --- Détecteurs 5 & 6 : plafonds de cadence (fenêtre) --------------------

    [Fact]
    public void Xp_rate_exceeded_is_flagged()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }, xp: 30),
            new RateWindow(TimeSpan.FromHours(1), XpInWindow: 590, AttemptsInWindow: 0));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.Flags.Should().Equal(IntegrityFlag.XpRateExceeded);
    }

    [Fact]
    public void Attempt_rate_exceeded_is_flagged()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }, xp: 5),
            new RateWindow(TimeSpan.FromHours(1), XpInWindow: 0, AttemptsInWindow: 40));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.Flags.Should().Equal(IntegrityFlag.AttemptRateExceeded);
    }

    [Fact]
    public void Rate_window_within_caps_does_not_flag()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }, xp: 30),
            new RateWindow(TimeSpan.FromHours(1), XpInWindow: 100, AttemptsInWindow: 5));

        verdict.IsClean.Should().BeTrue();
        verdict.Flags.Should().BeEmpty();
    }

    // --- Régression : la cadence ne sanctionne JAMAIS seule, même massive ----
    // Avant le plafond `CadenceContributionCeiling`, un excès XP ou tentatives d'environ
    // 30 % (projeté ≥ 1.3x le plafond) suffisait SEUL à atteindre RejectThreshold (0.8) —
    // un apprenant honnête enchaînant quelques leçons puis un examen réussi dans la même
    // heure pouvait perdre toutes ses récompenses sans avoir triché. Ces trois tests
    // épinglent la garantie : la cadence, seule ou combinée à elle-même, reste Flag.

    [Fact]
    public void Massive_solo_xp_rate_overage_stays_flagged_not_rejected()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }, xp: 100),
            new RateWindow(TimeSpan.FromHours(1), XpInWindow: 1000, AttemptsInWindow: 0));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.RiskScore.Should().BeApproximately(0.54, 1e-9);
        verdict.Flags.Should().Equal(IntegrityFlag.XpRateExceeded);
    }

    [Fact]
    public void Massive_solo_attempt_rate_overage_stays_flagged_not_rejected()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }, xp: 5),
            new RateWindow(TimeSpan.FromHours(1), XpInWindow: 0, AttemptsInWindow: 100));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.RiskScore.Should().BeApproximately(0.54, 1e-9);
        verdict.Flags.Should().Equal(IntegrityFlag.AttemptRateExceeded);
    }

    [Fact]
    public void Massive_combined_cadence_overage_still_stays_flagged_not_rejected()
    {
        // Les DEUX signaux de cadence à leur plafond (0.54 chacun) combinés via l'OR
        // probabiliste donnent ~0.7884 (< 0.8) : même un dépassement massif et simultané
        // des deux plafonds ne peut jamais, à lui seul, produire un Reject.
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }, xp: 100),
            new RateWindow(TimeSpan.FromHours(1), XpInWindow: 1000, AttemptsInWindow: 100));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.RiskScore.Should().BeApproximately(0.7884, 1e-3);
        verdict.Flags.Should().Equal(IntegrityFlag.XpRateExceeded, IntegrityFlag.AttemptRateExceeded);
    }

    // --- Combinaison probabiliste (OR) et ordre déterministe -----------------

    [Fact]
    public void Multiple_signals_combine_and_flags_are_ordered_by_enum()
    {
        // Bot évident : 5 items à 20 ms, temps réel 200 ms.
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(200, new[] { 20, 20, 20, 20, 20 }, xp: 50));

        verdict.Decision.Should().Be(IntegrityDecision.Reject);
        verdict.RiskScore.Should().BeApproximately(1d, 1e-9);
        verdict.Flags.Should().Equal(
            IntegrityFlag.SuperhumanItemSpeed,
            IntegrityFlag.AttemptTooFastOverall);
    }

    [Fact]
    public void Both_rate_caps_combine_via_probabilistic_or()
    {
        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 5000, 5000, 5000 }, xp: 30),
            new RateWindow(TimeSpan.FromHours(1), XpInWindow: 590, AttemptsInWindow: 40));

        verdict.Decision.Should().Be(IntegrityDecision.Flag);
        verdict.RiskScore.Should().BeApproximately(0.7783, 1e-3);
        verdict.Flags.Should().Equal(
            IntegrityFlag.XpRateExceeded,
            IntegrityFlag.AttemptRateExceeded);
    }

    // --- Politique injectable & garde-fous -----------------------------------

    [Fact]
    public void Custom_policy_can_relax_a_detector()
    {
        var lenient = IntegrityPolicy.Default with { SuperhumanItemFraction = 1.0 };

        var verdict = AttemptIntegrityEvaluator.Evaluate(
            Timing(60_000, new[] { 50, 50, 50, 5000, 5000 }),
            window: null,
            policy: lenient);

        verdict.IsClean.Should().BeTrue();
        verdict.Flags.Should().BeEmpty();
    }

    [Fact]
    public void Default_policy_exposes_calibrated_thresholds()
    {
        var policy = IntegrityPolicy.Default;

        policy.HumanFloorMs.Should().Be(350);
        policy.SuperhumanItemFraction.Should().Be(0.6);
        policy.MinItemsForSpeedChecks.Should().Be(3);
        policy.FlagThreshold.Should().Be(0.4);
        policy.RejectThreshold.Should().Be(0.8);
    }

    [Fact]
    public void Clean_verdict_has_clean_semantics()
    {
        IntegrityVerdict.Clean.IsClean.Should().BeTrue();
        IntegrityVerdict.Clean.Decision.Should().Be(IntegrityDecision.Allow);
        IntegrityVerdict.Clean.RiskScore.Should().Be(0d);
        IntegrityVerdict.Clean.Flags.Should().BeEmpty();
    }

    [Fact]
    public void Evaluate_throws_when_timing_is_null()
    {
        var act = () => AttemptIntegrityEvaluator.Evaluate(null!);

        act.Should().Throw<ArgumentNullException>();
    }
}
