using System.Text;
using Certigo.Domain.Content;

namespace Certigo.Domain.Tutor;

/// A single grounded teaching snippet the tutor is allowed to cite. Drawn from a
/// lesson's narrative blocks (hook/concept/example/recap) — never invented.
public sealed record TutorSnippet(string ConceptId, string Title, string Body);

/// Per-concept behavioural memory for one learner: how often they've attempted a
/// concept, how often they've missed it, the specific wrong options they tend to
/// pick (misconception fingerprints), and recency. This is the tutor's memory —
/// it grows with every answered item so the agent's help gets more personal.
public sealed record LearnerConceptStat(
    string ConceptId,
    int Attempts,
    int Correct,
    int Errors,
    int ConsecutiveErrors,
    IReadOnlyDictionary<string, int> WrongOptionTally,
    string? LastWrongOptionId,
    DateTimeOffset LastSeen)
{
    public static LearnerConceptStat Empty(string conceptId) =>
        new(conceptId, 0, 0, 0, 0, new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase), null, default);

    public double Accuracy => Attempts == 0 ? 0d : (double)Correct / Attempts;
}

/// The kind of movement an answer represents relative to the learner's history.
public enum LearnerTrend { Steady, Improving, Slipping }

/// Pure engine that evolves a learner's per-concept memory and reads signals from
/// it. Deterministic and side-effect free, so the agent's "learning" behaviour is
/// fully unit-testable without any store.
public static class LearnerModel
{
    public const int StruggleErrorThreshold = 2;
    public const int MasteryMinAttempts = 3;
    public const double MasteryAccuracy = 0.8d;

    /// Folds one answered item into the concept's running memory. The chosen wrong
    /// option (when incorrect) is tallied so the tutor can name the learner's
    /// signature misconception next time.
    public static LearnerConceptStat Observe(
        LearnerConceptStat? prior,
        string conceptId,
        bool correct,
        string? chosenWrongOptionId,
        DateTimeOffset now)
    {
        var s = prior ?? LearnerConceptStat.Empty(conceptId);
        var tally = new Dictionary<string, int>(s.WrongOptionTally, StringComparer.OrdinalIgnoreCase);
        var lastWrong = s.LastWrongOptionId;

        if (!correct && !string.IsNullOrWhiteSpace(chosenWrongOptionId))
        {
            tally[chosenWrongOptionId!] = tally.GetValueOrDefault(chosenWrongOptionId!) + 1;
            lastWrong = chosenWrongOptionId;
        }

        return s with
        {
            ConceptId = conceptId,
            Attempts = s.Attempts + 1,
            Correct = s.Correct + (correct ? 1 : 0),
            Errors = s.Errors + (correct ? 0 : 1),
            ConsecutiveErrors = correct ? 0 : s.ConsecutiveErrors + 1,
            WrongOptionTally = tally,
            LastWrongOptionId = lastWrong,
            LastSeen = now
        };
    }

    public static bool IsRecurringStruggle(LearnerConceptStat? s)
        => s is not null && (s.Errors >= StruggleErrorThreshold || s.ConsecutiveErrors >= StruggleErrorThreshold);

    public static bool IsMastered(LearnerConceptStat? s)
        => s is not null && s.Attempts >= MasteryMinAttempts && s.Accuracy >= MasteryAccuracy && s.ConsecutiveErrors == 0;

    /// The wrong option the learner picks most often for this concept (their
    /// signature misconception), with a deterministic tiebreak.
    public static string? TopConfusion(LearnerConceptStat? s)
    {
        if (s is null || s.WrongOptionTally.Count == 0)
        {
            return null;
        }

        return s.WrongOptionTally
            .OrderByDescending(kv => kv.Value)
            .ThenBy(kv => kv.Key, StringComparer.Ordinal)
            .First().Key;
    }

    public static LearnerTrend TrendFor(LearnerConceptStat? prior, bool correct)
    {
        if (IsRecurringStruggle(prior) && correct)
        {
            return LearnerTrend.Improving;
        }

        if (IsMastered(prior) && !correct)
        {
            return LearnerTrend.Slipping;
        }

        return LearnerTrend.Steady;
    }
}

/// Snapshot of what the tutor knows about this learner *for the concept under
/// test*, computed from their history *before* the current answer. Drives the
/// personalised tone, the misconception callout, and the recommendation.
public sealed record TutorLearnerSignals(
    int Attempts,
    int Errors,
    double Accuracy,
    bool RecurringStruggle,
    bool MasteredBefore,
    string? TopConfusedOptionLabel,
    LearnerTrend Trend)
{
    public static readonly TutorLearnerSignals None =
        new(0, 0, 0d, false, false, null, LearnerTrend.Steady);
}

/// Everything the tutor needs to explain one answered item, grounded entirely in
/// the public lesson plus its server-side answer key. Pure data: no I/O, no LLM.
public sealed record TutorContext(
    string TrackCode,
    string TrackTitle,
    string LessonTitle,
    string ItemId,
    string ConceptId,
    string Stem,
    bool IsCorrect,
    IReadOnlyList<string> ChosenLabels,
    IReadOnlyList<string> CorrectLabels,
    string KeyExplanation,
    IReadOnlyList<TutorSnippet> Snippets,
    TutorLearnerSignals Learner)
{
    /// The closed set of concept ids the tutor may cite. Anything outside this
    /// set is, by definition, a hallucination and is rejected by the guardrails.
    public IReadOnlyList<string> GroundedConceptIds =>
        Snippets.Select(s => s.ConceptId)
            .Append(ConceptId)
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
}

/// A structured tutor reply. <see cref="Source"/> distinguishes the deterministic
/// grounded composer ("grounded") from a guardrail-passed LLM completion ("ai").
/// <see cref="Recommendation"/> is always grounded and personalised — the agent's
/// "what to do next" — regardless of source.
public sealed record TutorExplanation(
    string Headline,
    IReadOnlyList<string> Points,
    string Encouragement,
    IReadOnlyList<string> CitedConceptIds,
    string Recommendation,
    string Source);

public sealed record TutorGuardrailResult(bool Ok, IReadOnlyList<string> Violations);

/// Projects a public lesson + its answer-key item into a fully grounded
/// <see cref="TutorContext"/>. Pure and deterministic so the selection logic can
/// be unit-tested without any repository or network.
public static class TutorContextFactory
{
    private const int MaxSnippets = 4;

    private static readonly HashSet<string> NarrativeBlockTypes =
        new(StringComparer.OrdinalIgnoreCase) { "hook", "concept", "example", "recap" };

    public static TutorContext Create(
        Track track,
        Lesson lesson,
        AnswerKeyItem keyItem,
        IReadOnlyList<string> chosenOptionIds,
        LearnerConceptStat? priorStat = null)
    {
        var check = lesson.Blocks
            .Select(b => b.Check)
            .FirstOrDefault(c => c is not null && string.Equals(c.Id, keyItem.ItemId, StringComparison.OrdinalIgnoreCase));

        var labelById = check?.Options.ToDictionary(o => o.Id, o => o.Label, StringComparer.OrdinalIgnoreCase)
            ?? new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        var chosen = (chosenOptionIds ?? Array.Empty<string>())
            .Select(id => labelById.TryGetValue(id, out var label) ? label : id)
            .ToArray();
        var correct = keyItem.Correct
            .Select(id => labelById.TryGetValue(id, out var label) ? label : id)
            .ToArray();

        var isCorrect = SetEquals(chosenOptionIds ?? Array.Empty<string>(), keyItem.Correct);

        // Concept under test first, then the rest of the lesson in document order,
        // so the most relevant teaching always leads. De-duplicated by body.
        var snippets = lesson.Blocks
            .Where(b => NarrativeBlockTypes.Contains(b.Type) && !string.IsNullOrWhiteSpace(b.Body))
            .Select(b => new TutorSnippet(b.ConceptId, Humanize(b.Title, b.Type), b.Body!.Trim()))
            .GroupBy(s => s.Body, StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .OrderByDescending(s => string.Equals(s.ConceptId, keyItem.ConceptId, StringComparison.OrdinalIgnoreCase))
            .Take(MaxSnippets)
            .ToArray();

        var learner = BuildSignals(priorStat, isCorrect, labelById);

        return new TutorContext(
            track.Code,
            track.Title,
            lesson.Title,
            keyItem.ItemId,
            keyItem.ConceptId,
            check?.Stem ?? string.Empty,
            isCorrect,
            chosen,
            correct,
            keyItem.Explanation,
            snippets,
            learner);
    }

    /// Reads the learner's history (before this answer) into the signals the tutor
    /// personalises on, resolving their signature wrong option to a human label.
    private static TutorLearnerSignals BuildSignals(
        LearnerConceptStat? priorStat,
        bool isCorrect,
        IReadOnlyDictionary<string, string> labelById)
    {
        if (priorStat is null)
        {
            return TutorLearnerSignals.None;
        }

        var topConfusionId = LearnerModel.TopConfusion(priorStat);
        string? topConfusionLabel = null;
        if (topConfusionId is not null)
        {
            topConfusionLabel = labelById.TryGetValue(topConfusionId, out var label) ? label : topConfusionId;
        }

        return new TutorLearnerSignals(
            priorStat.Attempts,
            priorStat.Errors,
            priorStat.Accuracy,
            LearnerModel.IsRecurringStruggle(priorStat),
            LearnerModel.IsMastered(priorStat),
            topConfusionLabel,
            LearnerModel.TrendFor(priorStat, isCorrect));
    }

    private static bool SetEquals(IReadOnlyList<string> a, IReadOnlyList<string> b)
    {
        var left = a.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        var right = b.OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        return left.SequenceEqual(right, StringComparer.OrdinalIgnoreCase);
    }

    private static string Humanize(string? title, string type)
    {
        if (!string.IsNullOrWhiteSpace(title))
        {
            return title!.Trim();
        }

        if (string.IsNullOrWhiteSpace(type))
        {
            return "Concept";
        }

        return char.ToUpperInvariant(type[0]) + type[1..].ToLowerInvariant();
    }
}

/// Builds the deterministic, fully grounded explanation. This is both the
/// free/offline tutor experience and the faithful "ground truth" an LLM upgrade
/// is held to. No punishment on a miss (ADR-06): tone stays encouraging.
public static class TutorComposer
{
    private const int MaxBodyChars = 240;
    private const int MaxRenderedSnippets = 2;

    public static TutorExplanation Compose(TutorContext ctx)
    {
        var headline = Headline(ctx);

        var points = new List<string>();
        var cited = new List<string>();

        if (!string.IsNullOrWhiteSpace(ctx.KeyExplanation))
        {
            points.Add(ctx.KeyExplanation.Trim());
        }

        if (!ctx.IsCorrect && ctx.CorrectLabels.Count > 0)
        {
            var correct = string.Join(", ", ctx.CorrectLabels);
            if (ctx.ChosenLabels.Count > 0)
            {
                var chosen = string.Join(", ", ctx.ChosenLabels);
                points.Add($"You picked \"{chosen}\", but the answer is \"{correct}\".");
            }
            else
            {
                points.Add($"The answer is \"{correct}\".");
            }
        }

        // Personalised callouts drawn from the learner's own history. These make
        // the agent feel like it remembers you — the heart of "continuous learning".
        foreach (var note in PersonalNotes(ctx))
        {
            points.Add(note);
        }

        if (!string.IsNullOrWhiteSpace(ctx.ConceptId))
        {
            cited.Add(ctx.ConceptId);
        }

        foreach (var snippet in ctx.Snippets.Take(MaxRenderedSnippets))
        {
            points.Add($"{snippet.Title}: {Trim(snippet.Body, MaxBodyChars)}");
            if (!string.IsNullOrWhiteSpace(snippet.ConceptId))
            {
                cited.Add(snippet.ConceptId);
            }
        }

        var encouragement = Encouragement(ctx);
        var recommendation = Recommendation(ctx);

        var citedConcepts = cited
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new TutorExplanation(headline, points, encouragement, citedConcepts, recommendation, "grounded");
    }

    private static string Headline(TutorContext ctx)
    {
        if (ctx.IsCorrect && ctx.Learner.Trend == LearnerTrend.Improving)
        {
            return "Big improvement — you turned this one around!";
        }

        if (!ctx.IsCorrect && ctx.Learner.RecurringStruggle)
        {
            return "This one keeps tripping you up — let's lock it in.";
        }

        if (!ctx.IsCorrect && ctx.Learner.Trend == LearnerTrend.Slipping)
        {
            return "You usually nail this — let's refresh it.";
        }

        return ctx.IsCorrect
            ? "Nice — here's why that's right."
            : "Not quite — let's unpack it.";
    }

    private static IEnumerable<string> PersonalNotes(TutorContext ctx)
    {
        var learner = ctx.Learner;

        if (!ctx.IsCorrect && learner.Errors > 0)
        {
            yield return $"You've practised this concept {learner.Attempts}× and missed it {learner.Errors}× — we'll keep working it.";
        }

        if (!ctx.IsCorrect
            && !string.IsNullOrWhiteSpace(learner.TopConfusedOptionLabel)
            && !ctx.ChosenLabels.Contains(learner.TopConfusedOptionLabel!, StringComparer.OrdinalIgnoreCase))
        {
            yield return $"Your usual trap here is \"{learner.TopConfusedOptionLabel}\" — good that you avoided it this time.";
        }
        else if (!ctx.IsCorrect && !string.IsNullOrWhiteSpace(learner.TopConfusedOptionLabel))
        {
            yield return $"This is the same option you tend to fall for — \"{learner.TopConfusedOptionLabel}\". Let's break that habit.";
        }

        if (ctx.IsCorrect && learner.Trend == LearnerTrend.Improving)
        {
            yield return "You've struggled with this before and just got it right — real progress.";
        }
    }

    private static string Encouragement(TutorContext ctx)
    {
        if (ctx.IsCorrect && ctx.Learner.Trend == LearnerTrend.Improving)
        {
            return "That's exactly how mastery is built — one comeback at a time.";
        }

        if (!ctx.IsCorrect && ctx.Learner.RecurringStruggle)
        {
            return "Tricky concepts take a few passes — you're closing the gap.";
        }

        return ctx.IsCorrect
            ? "Keep that momentum going."
            : "Every miss sharpens your readiness — you've got this.";
    }

    private static string Recommendation(TutorContext ctx)
    {
        if (!ctx.IsCorrect || ctx.Learner.RecurringStruggle)
        {
            return $"Re-open \"{ctx.LessonTitle}\" and retry this concept next session — I'll keep tracking how you do.";
        }

        if (ctx.IsCorrect && ctx.Learner.MasteredBefore)
        {
            return "You've got this concept down — ready to move on to the next one.";
        }

        return "Solid — a quick review tomorrow will cement it for the long term.";
    }

    private static string Trim(string body, int max)
    {
        var clean = body.Trim();
        if (clean.Length <= max)
        {
            return clean;
        }

        return clean[..max].TrimEnd() + "…";
    }
}

/// Server-side validation for any tutor explanation — especially an LLM-produced
/// one. Enforces grounding (no invented concepts), length sanity, and exam
/// integrity (no claims of leaked/real exam content or guaranteed passing).
public static class TutorGuardrails
{
    private const int MaxHeadlineChars = 160;
    private const int MaxPointChars = 600;
    private const int MaxEncouragementChars = 240;
    private const int MaxRecommendationChars = 320;
    private const int MaxPoints = 8;

    private static readonly string[] BannedPhrases =
    {
        "real exam question",
        "actual exam question",
        "real exam questions",
        "actual exam questions",
        "guaranteed to pass",
        "guarantee you pass",
        "100% pass",
        "brain dump",
        "braindump",
        "leaked exam",
        "exam leak"
    };

    public static TutorGuardrailResult Validate(TutorExplanation explanation, TutorContext ctx)
    {
        var violations = new List<string>();

        if (string.IsNullOrWhiteSpace(explanation.Headline))
        {
            violations.Add("headline.empty");
        }
        else if (explanation.Headline.Length > MaxHeadlineChars)
        {
            violations.Add("headline.too_long");
        }

        if (explanation.Points.Count == 0)
        {
            violations.Add("points.empty");
        }
        else if (explanation.Points.Count > MaxPoints)
        {
            violations.Add("points.too_many");
        }

        if (explanation.Points.Any(p => string.IsNullOrWhiteSpace(p)))
        {
            violations.Add("points.blank_entry");
        }

        if (explanation.Points.Any(p => p.Length > MaxPointChars))
        {
            violations.Add("points.too_long");
        }

        if (explanation.Encouragement.Length > MaxEncouragementChars)
        {
            violations.Add("encouragement.too_long");
        }

        if (string.IsNullOrWhiteSpace(explanation.Recommendation))
        {
            violations.Add("recommendation.empty");
        }
        else if (explanation.Recommendation.Length > MaxRecommendationChars)
        {
            violations.Add("recommendation.too_long");
        }

        var grounded = new HashSet<string>(ctx.GroundedConceptIds, StringComparer.OrdinalIgnoreCase);
        foreach (var concept in explanation.CitedConceptIds)
        {
            if (!grounded.Contains(concept))
            {
                violations.Add($"cited.ungrounded:{concept}");
            }
        }

        var haystack = BuildHaystack(explanation);
        foreach (var phrase in BannedPhrases)
        {
            if (haystack.Contains(phrase, StringComparison.OrdinalIgnoreCase))
            {
                violations.Add($"integrity.banned_phrase:{phrase}");
            }
        }

        return new TutorGuardrailResult(violations.Count == 0, violations);
    }

    private static string BuildHaystack(TutorExplanation explanation)
    {
        var sb = new StringBuilder();
        sb.Append(explanation.Headline).Append('\n');
        foreach (var point in explanation.Points)
        {
            sb.Append(point).Append('\n');
        }

        sb.Append(explanation.Encouragement).Append('\n');
        sb.Append(explanation.Recommendation);
        return sb.ToString();
    }
}

/// Assembles the system + user prompts handed to an LLM. The system prompt pins
/// the persona, the strict grounding contract, the integrity rules, and the exact
/// JSON response schema the service parses back. Pure string building, testable.
public static class TutorPromptBuilder
{
    public static string System() =>
        """
        You are Nimbus, the friendly cloud mascot and Azure certification tutor for Certigo.
        Your job: explain why a learner's answer to a practice item is right or wrong.

        Hard rules:
        - Ground every statement ONLY in the concepts and explanation provided in the context.
          Never introduce Azure services, facts, or concept ids that are not in the context.
        - Only cite conceptIds from the provided "Grounded concept ids" allowlist.
        - Never claim to reproduce real, actual, or leaked exam questions, and never promise a guaranteed pass.
        - Be concise, concrete, and encouraging. Never shame a wrong answer; frame mistakes as progress.

        Respond with a single JSON object and nothing else, matching exactly:
        {
          "headline": "one short sentence",
          "points": ["1-4 short teaching points"],
          "encouragement": "one encouraging sentence",
          "citedConceptIds": ["conceptIds you used, all from the allowlist"]
        }
        """;

    public static string User(TutorContext ctx)
    {
        var sb = new StringBuilder();
        sb.Append("Track: ").Append(ctx.TrackCode).Append(" — ").Append(ctx.TrackTitle).Append('\n');
        sb.Append("Lesson: ").Append(ctx.LessonTitle).Append('\n');
        sb.Append("Question: ").Append(ctx.Stem).Append('\n');
        sb.Append("Learner was ").Append(ctx.IsCorrect ? "correct" : "incorrect").Append(".\n");

        if (ctx.ChosenLabels.Count > 0)
        {
            sb.Append("Learner chose: ").Append(string.Join(", ", ctx.ChosenLabels)).Append('\n');
        }

        if (ctx.CorrectLabels.Count > 0)
        {
            sb.Append("Correct answer: ").Append(string.Join(", ", ctx.CorrectLabels)).Append('\n');
        }

        if (!string.IsNullOrWhiteSpace(ctx.KeyExplanation))
        {
            sb.Append("Authoritative explanation: ").Append(ctx.KeyExplanation.Trim()).Append('\n');
        }

        sb.Append("Grounded concept ids: ").Append(string.Join(", ", ctx.GroundedConceptIds)).Append('\n');

        AppendLearnerHistory(sb, ctx.Learner);

        if (ctx.Snippets.Count > 0)
        {
            sb.Append("Grounded teaching snippets:\n");
            foreach (var snippet in ctx.Snippets)
            {
                sb.Append("- [").Append(snippet.ConceptId).Append("] ")
                    .Append(snippet.Title).Append(": ").Append(snippet.Body).Append('\n');
            }
        }

        sb.Append("\nExplain the result, grounded only in the above.");
        return sb.ToString();
    }

    /// Surfaces the learner's history so an LLM upgrade personalises the same way
    /// the grounded composer does. Only emitted when there is real history.
    private static void AppendLearnerHistory(StringBuilder sb, TutorLearnerSignals learner)
    {
        if (learner.Attempts == 0)
        {
            return;
        }

        sb.Append("Learner history for this concept: attempts=").Append(learner.Attempts)
            .Append(", errors=").Append(learner.Errors)
            .Append(", accuracy=").Append((int)Math.Round(learner.Accuracy * 100)).Append('%')
            .Append(", recurringStruggle=").Append(learner.RecurringStruggle ? "yes" : "no")
            .Append(", masteredBefore=").Append(learner.MasteredBefore ? "yes" : "no")
            .Append(", trend=").Append(learner.Trend.ToString().ToLowerInvariant())
            .Append('\n');

        if (!string.IsNullOrWhiteSpace(learner.TopConfusedOptionLabel))
        {
            sb.Append("Learner's most common wrong choice here: \"")
                .Append(learner.TopConfusedOptionLabel).Append("\".\n");
        }

        if (learner.RecurringStruggle)
        {
            sb.Append("This concept is a recurring struggle — be extra supportive, concrete, and specific.\n");
        }
    }
}
