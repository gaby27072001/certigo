namespace Microlingo.Domain.Gamification;

/// The measurable behaviours a daily quest can track. Each maps to a per-day
/// signal the server already computes from the quiz flow, so quest progress is
/// always recomputable and never trusted from the client.
public enum QuestKind
{
    EarnXp,
    CompleteLessons,
    AnswerCorrect,
    FlawlessLesson
}

public sealed record QuestTemplate(string Id, QuestKind Kind, string Title, int Target, int RewardGems);

/// Snapshot of a learner's activity for a single day, used to evaluate quests.
public sealed record DailySignals(int XpEarned, int LessonsCompleted, int CorrectAnswers, int PerfectLessons)
{
    public static readonly DailySignals Empty = new(0, 0, 0, 0);
}

public sealed record QuestStatus(QuestTemplate Template, int Current, bool Completed);

/// Pure, deterministic daily-quest rules. The same learner gets the same three
/// quests for a given calendar day (so the board is stable across reads), and
/// quest progress is derived purely from <see cref="DailySignals"/>.
public static class QuestEngine
{
    public const int DailyCount = 3;

    public static readonly IReadOnlyList<QuestTemplate> Pool = new[]
    {
        new QuestTemplate("earn-xp-30", QuestKind.EarnXp, "Gagne 30 XP aujourd'hui", 30, 15),
        new QuestTemplate("earn-xp-60", QuestKind.EarnXp, "Gagne 60 XP aujourd'hui", 60, 25),
        new QuestTemplate("complete-2-lessons", QuestKind.CompleteLessons, "Termine 2 leçons", 2, 15),
        new QuestTemplate("complete-3-lessons", QuestKind.CompleteLessons, "Termine 3 leçons", 3, 25),
        new QuestTemplate("answer-correct-10", QuestKind.AnswerCorrect, "Réponds juste 10 fois", 10, 15),
        new QuestTemplate("answer-correct-20", QuestKind.AnswerCorrect, "Réponds juste 20 fois", 20, 25),
        new QuestTemplate("flawless-lesson", QuestKind.FlawlessLesson, "Réussis une leçon sans faute", 1, 20)
    };

    /// Selects <paramref name="count"/> quests of distinct kinds for the day,
    /// deterministically seeded by the learner id and date.
    public static IReadOnlyList<QuestTemplate> DailyQuests(DateOnly date, string userId, int count = DailyCount)
    {
        var rng = new Lcg(StableSeed(userId, date));

        var kinds = Pool.Select(t => t.Kind).Distinct().ToArray();
        Shuffle(kinds, rng);

        var take = Math.Min(count, kinds.Length);
        var result = new List<QuestTemplate>(take);
        for (var i = 0; i < take; i++)
        {
            var variants = Pool.Where(t => t.Kind == kinds[i]).ToArray();
            result.Add(variants[rng.Next(variants.Length)]);
        }

        return result;
    }

    public static QuestStatus Evaluate(QuestTemplate template, DailySignals signals)
    {
        var raw = Progress(template.Kind, signals);
        return new QuestStatus(template, Math.Min(raw, template.Target), raw >= template.Target);
    }

    public static int Progress(QuestKind kind, DailySignals signals) => kind switch
    {
        QuestKind.EarnXp => signals.XpEarned,
        QuestKind.CompleteLessons => signals.LessonsCompleted,
        QuestKind.AnswerCorrect => signals.CorrectAnswers,
        QuestKind.FlawlessLesson => signals.PerfectLessons,
        _ => 0
    };

    private static void Shuffle<T>(T[] items, Lcg rng)
    {
        for (var i = items.Length - 1; i > 0; i--)
        {
            var j = rng.Next(i + 1);
            (items[i], items[j]) = (items[j], items[i]);
        }
    }

    private static int StableSeed(string userId, DateOnly date)
    {
        unchecked
        {
            var hash = 17;
            foreach (var c in userId)
            {
                hash = (hash * 31) + c;
            }

            return (hash * 31) + date.DayNumber;
        }
    }

    /// Tiny deterministic linear-congruential generator. Platform-independent so
    /// quest selection is identical on every server and in tests.
    private sealed class Lcg(int seed)
    {
        private uint _state = (uint)seed;

        public int Next(int maxExclusive)
        {
            unchecked
            {
                _state = (_state * 1664525u) + 1013904223u;
            }

            return (int)(((_state >> 16) & 0x7fff) % (uint)Math.Max(1, maxExclusive));
        }
    }
}
