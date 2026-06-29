namespace Certigo.Domain.Integrity;

// Anti-triche — autorité serveur (§5 « Backend à compléter », §6 sécurité CISO,
// §15 risque « Triche économie/XP → Intégrité ligues »).
//
// Ce moteur est une fonction PURE et DÉTERMINISTE : à partir des seuls faits
// observables d'une tentative (quand elle a commencé, quand elle a été soumise,
// le temps de réponse par item, l'XP gagnée) il rend un verdict d'intégrité.
// Il ne lit aucun état, n'a aucun effet de bord, et ne dépend pas de l'horloge :
// il est donc trivialement testable et rejouable.
//
// Le rejeu (double soumission) est traité EN AMONT par l'idempotence
// `clientAttemptId` des services (qui renvoient `prior.Result` avant toute
// notation) ; ce n'est donc volontairement PAS une entrée de ce moteur.
//
// Mode SANCTION : le verdict est appliqué par les services. `Reject` (signaux
// durs : horloge falsifiée, vitesse bot — risk ≥ 0.8) SUPPRIME les récompenses
// (0 XP/gems, pas de ligue, pas d'upsert profil) ET émet `attempt.flagged`.
// `Flag` (cadence 0.4–0.8) reste en détection : récompenses créditées +
// `attempt.flagged`. `Allow` passe sans event. La fenêtre de cadence 1h
// (débit XP / nb tentatives) est alimentée par une `RateWindow` réelle lue du
// conteneur `attempts`.

/// <summary>
/// Décision du serveur sur une tentative notée. <see cref="Allow"/> laisse passer,
/// <see cref="Flag"/> signale pour observation/revue sans punir, <see cref="Reject"/>
/// marque une tentative à ne pas récompenser (appliqué au lot d'exécution).
/// </summary>
public enum IntegrityDecision
{
    Allow,
    Flag,
    Reject
}

/// <summary>
/// Anomalie précise et nommée détectée sur une tentative. Plusieurs peuvent
/// coexister ; l'ordre de l'énumération est l'ordre de restitution (déterministe).
/// </summary>
public enum IntegrityFlag
{
    /// <summary>La tentative déclare avoir été soumise avant d'avoir commencé (horloge falsifiée).</summary>
    SubmittedBeforeStarted,

    /// <summary>Une majorité d'items répondus sous le plancher humain de lecture/décision.</summary>
    SuperhumanItemSpeed,

    /// <summary>Le temps réel total écoulé est très en deçà du minimum humain pour ce nombre d'items.</summary>
    AttemptTooFastOverall,

    /// <summary>La somme des temps par item revendiqués dépasse largement le temps réel écoulé (latences fabriquées).</summary>
    InconsistentLatencies,

    /// <summary>L'XP cumulée sur une fenêtre récente dépasse le plafond (farming d'XP).</summary>
    XpRateExceeded,

    /// <summary>Le nombre de tentatives sur une fenêtre récente dépasse le plafond (spam de soumissions).</summary>
    AttemptRateExceeded
}

/// <summary>
/// Faits temporels observables d'une tentative soumise. <paramref name="ItemLatenciesMs"/>
/// est le temps de réponse revendiqué par le client pour chaque item soumis.
/// </summary>
public sealed record AttemptTiming(
    DateTimeOffset StartedAt,
    DateTimeOffset SubmittedAt,
    IReadOnlyList<int> ItemLatenciesMs,
    int XpEarned)
{
    /// <summary>Temps réel écoulé. Peut être négatif si l'horloge cliente a été falsifiée.</summary>
    public TimeSpan WallClock => SubmittedAt - StartedAt;
}

/// <summary>
/// Agrégat d'activité récente d'un apprenant sur une fenêtre glissante. Optionnel :
/// fourni par l'appelant (Redis en production) pour activer les détecteurs de cadence.
/// </summary>
public sealed record RateWindow(
    TimeSpan Duration,
    int XpInWindow,
    int AttemptsInWindow);

/// <summary>
/// Seuils calibrés du moteur. Centralisés ici pour qu'un seul endroit gouverne la
/// sensibilité, et pour pouvoir durcir/assouplir via configuration au lot cloud.
/// </summary>
public sealed record IntegrityPolicy(
    int HumanFloorMs,
    double SuperhumanItemFraction,
    int MinItemsForSpeedChecks,
    int MinPerItemMs,
    double OverallSpeedFactor,
    double LatencyOverrunFactor,
    int MaxXpPerWindow,
    int MaxAttemptsPerWindow,
    double FlagThreshold,
    double RejectThreshold)
{
    /// <summary>
    /// Valeurs par défaut volontairement conservatrices : on ne veut JAMAIS punir un
    /// apprenant honnête. Un humain ne lit pas un énoncé + ses options en moins de
    /// 350 ms ; on n'évalue la vitesse qu'à partir de 3 items (un tap chanceux rapide
    /// n'est pas de la triche) ; il faut une MAJORITÉ d'items sous le plancher pour
    /// suspecter un bot.
    ///
    /// Calibration sanction (conservée, ne pas durcir sans test dédié) :
    /// la cadence (MaxXpPerWindow 600, MaxAttemptsPerWindow 40/1h) plafonne à
    /// FlagThreshold 0.4 → un débit excessif seul donne au plus un `Flag`
    /// (récompenses conservées), jamais un `Reject` solo. Le `Reject` (≥ 0.8) est
    /// réservé aux signaux durs : soumission avant départ (risk 1) ou vitesse
    /// surhumaine cumulée. Marge 0.4 entre Flag et Reject = aucun faux positif punitif.
    /// </summary>
    public static IntegrityPolicy Default { get; } = new(
        HumanFloorMs: 350,
        SuperhumanItemFraction: 0.6,
        MinItemsForSpeedChecks: 3,
        MinPerItemMs: 800,
        OverallSpeedFactor: 0.5,
        LatencyOverrunFactor: 1.5,
        MaxXpPerWindow: 600,
        MaxAttemptsPerWindow: 40,
        FlagThreshold: 0.4,
        RejectThreshold: 0.8);
}

/// <summary>
/// Verdict d'intégrité : la décision, un score de risque continu [0..1] (utile pour
/// le tri/observabilité) et la liste déterministe des anomalies détectées.
/// </summary>
public sealed record IntegrityVerdict(
    IntegrityDecision Decision,
    double RiskScore,
    IReadOnlyList<IntegrityFlag> Flags)
{
    /// <summary>Vrai quand la tentative est laissée passer sans réserve.</summary>
    public bool IsClean => Decision == IntegrityDecision.Allow;

    /// <summary>Verdict propre partagé : risque nul, aucune anomalie.</summary>
    public static IntegrityVerdict Clean { get; } =
        new(IntegrityDecision.Allow, 0d, Array.Empty<IntegrityFlag>());
}

/// <summary>
/// Évalue l'intégrité d'une tentative. Fonction pure : mêmes entrées ⇒ même verdict.
/// </summary>
public static class AttemptIntegrityEvaluator
{
    /// <summary>
    /// Rend un <see cref="IntegrityVerdict"/> pour une tentative. <paramref name="window"/>
    /// est optionnel (active les plafonds de cadence). <paramref name="policy"/> est
    /// optionnel (utilise <see cref="IntegrityPolicy.Default"/> sinon).
    /// </summary>
    public static IntegrityVerdict Evaluate(
        AttemptTiming timing,
        RateWindow? window = null,
        IntegrityPolicy? policy = null)
    {
        ArgumentNullException.ThrowIfNull(timing);
        policy ??= IntegrityPolicy.Default;

        var wallMs = timing.WallClock.TotalMilliseconds;

        // 1. Cohérence temporelle (DÉTECTEUR DUR) : une tentative qui prétend avoir
        //    été soumise avant d'avoir commencé est physiquement impossible — horloge
        //    cliente falsifiée. Rejet immédiat, sans plus de notation.
        if (wallMs < 0)
        {
            return new IntegrityVerdict(
                IntegrityDecision.Reject,
                1d,
                new[] { IntegrityFlag.SubmittedBeforeStarted });
        }

        // SortedSet : déduplique et restitue dans l'ordre de l'énumération (déterministe).
        var flags = new SortedSet<IntegrityFlag>();
        var latencies = timing.ItemLatenciesMs ?? Array.Empty<int>();
        var itemCount = latencies.Count;
        var risk = 0d;

        // Les détecteurs de vitesse ne s'exécutent qu'au-delà d'un minimum d'items :
        // en deçà, un verdict de vitesse n'est pas statistiquement significatif.
        if (itemCount >= policy.MinItemsForSpeedChecks)
        {
            var subFloor = 0;
            double sumMs = 0;
            foreach (var latency in latencies)
            {
                var safe = latency < 0 ? 0 : latency;
                sumMs += safe;
                if (safe < policy.HumanFloorMs)
                {
                    subFloor++;
                }
            }

            // 2. Vitesse surhumaine par item : un humain ne peut pas répondre sous le
            //    plancher de lecture. Quelques reconnaissances rapides sont normales ;
            //    une MAJORITÉ d'items sous le plancher trahit un bot.
            var subFloorFraction = (double)subFloor / itemCount;
            if (subFloorFraction >= policy.SuperhumanItemFraction)
            {
                flags.Add(IntegrityFlag.SuperhumanItemSpeed);
                risk = Combine(risk, subFloorFraction);
            }

            // 3. Plancher de temps réel agrégé : toute la tentative s'est écoulée en
            //    bien moins de temps réel que le minimum humain pour ce nombre d'items.
            var expectedMinMs = itemCount * (double)policy.MinPerItemMs * policy.OverallSpeedFactor;
            if (expectedMinMs > 0 && wallMs < expectedMinMs)
            {
                flags.Add(IntegrityFlag.AttemptTooFastOverall);
                risk = Combine(risk, 1d - (wallMs / expectedMinMs));
            }

            // 4. Cohérence interne : la somme des temps par item revendiqués ne peut
            //    pas excéder largement le temps réel écoulé — sinon les latences sont
            //    fabriquées/rejouées (charge utile internement incohérente).
            var budgetMs = wallMs * policy.LatencyOverrunFactor;
            if (sumMs > budgetMs)
            {
                flags.Add(IntegrityFlag.InconsistentLatencies);
                var denom = budgetMs <= 0 ? sumMs : budgetMs;
                risk = Combine(risk, Math.Min((sumMs - budgetMs) / denom, 1d));
            }
        }

        // 5 & 6. Plafonds de cadence sur fenêtre récente — gardes anti-farming d'XP et
        //        anti-spam de soumissions. Évalués seulement si l'appelant fournit la
        //        fenêtre agrégée (Redis en production).
        if (window is not null)
        {
            var projectedXp = window.XpInWindow + timing.XpEarned;
            if (policy.MaxXpPerWindow > 0 && projectedXp > policy.MaxXpPerWindow)
            {
                flags.Add(IntegrityFlag.XpRateExceeded);
                var excess = (double)(projectedXp - policy.MaxXpPerWindow) / policy.MaxXpPerWindow;
                risk = Combine(risk, Math.Min(0.5 + excess, 1d));
            }

            var projectedAttempts = window.AttemptsInWindow + 1;
            if (policy.MaxAttemptsPerWindow > 0 && projectedAttempts > policy.MaxAttemptsPerWindow)
            {
                flags.Add(IntegrityFlag.AttemptRateExceeded);
                var excess = (double)(projectedAttempts - policy.MaxAttemptsPerWindow) / policy.MaxAttemptsPerWindow;
                risk = Combine(risk, Math.Min(0.5 + excess, 1d));
            }
        }

        risk = Math.Clamp(risk, 0d, 1d);
        var decision = risk >= policy.RejectThreshold
            ? IntegrityDecision.Reject
            : risk >= policy.FlagThreshold
                ? IntegrityDecision.Flag
                : IntegrityDecision.Allow;

        if (decision == IntegrityDecision.Allow && flags.Count == 0)
        {
            return IntegrityVerdict.Clean;
        }

        return new IntegrityVerdict(decision, Math.Round(risk, 4), flags.ToArray());
    }

    // OU probabiliste : des signaux de risque indépendants s'accumulent sans jamais
    // dépasser 1. risk' = 1 - (1 - risk)·(1 - contribution).
    private static double Combine(double current, double contribution)
    {
        var clamped = Math.Clamp(contribution, 0d, 1d);
        return 1d - ((1d - current) * (1d - clamped));
    }
}
