using Certigo.Domain.Content;

namespace Certigo.Domain.Exam;

/// A single candidate exam item, projected from a lesson answer key. Carries
/// just enough metadata for blueprint apportionment, adaptive selection and
/// weighted scoring — never the correct answer (grading stays in the key).
public sealed record ExamItemRef(
    string ItemId,
    string LessonId,
    string DomainId,
    string ConceptId,
    ItemType Type,
    int Difficulty);

/// The per-domain slot allocation of a mock-exam blueprint.
public sealed record ExamBlueprintDomain(string DomainId, string Name, double Weight, int ItemCount);

/// One exam domain's contribution to a graded mock exam.
public sealed record ExamDomainScore(string DomainId, string Name, double Weight, int Correct, int Total, int Pct);

/// The graded result of a mock exam: a Microsoft-style scaled score (1–1000,
/// pass at 700 by default) plus the weighted per-domain breakdown.
public sealed record ExamScore(
    int ScaledScore,
    int Pct,
    bool Passed,
    int PassingScore,
    int Correct,
    int Total,
    IReadOnlyList<ExamDomainScore> Domains);

/// Hamilton (largest-remainder) apportionment of exam items across weighted
/// exam domains. Guarantees the per-domain counts sum exactly to the requested
/// length and that every domain gets at least one item (when the length can
/// cover them) so no objective area is ever invisible on a practice exam.
public static class MockExamBlueprint
{
    public static IReadOnlyList<ExamBlueprintDomain> Apportion(
        IReadOnlyList<(string DomainId, string Name, double Weight)> domains,
        int totalItems)
    {
        if (domains.Count == 0 || totalItems <= 0)
        {
            return Array.Empty<ExamBlueprintDomain>();
        }

        var totalWeight = domains.Sum(d => Math.Max(0, d.Weight));
        if (totalWeight <= 0)
        {
            // Degenerate weights: fall back to an even split.
            totalWeight = domains.Count;
        }

        var ideal = domains
            .Select(d => totalItems * Math.Max(0, d.Weight <= 0 ? 1 : d.Weight) / totalWeight)
            .ToArray();

        var counts = ideal.Select(x => (int)Math.Floor(x)).ToArray();
        var assigned = counts.Sum();
        var remaining = totalItems - assigned;

        // Hand the remaining seats to the largest fractional remainders.
        var order = Enumerable.Range(0, domains.Count)
            .OrderByDescending(i => ideal[i] - counts[i])
            .ThenBy(i => i)
            .ToArray();

        for (var k = 0; k < remaining; k++)
        {
            counts[order[k % order.Length]]++;
        }

        if (totalItems >= domains.Count)
        {
            EnsureMinimumOne(counts);
        }

        return domains
            .Select((d, i) => new ExamBlueprintDomain(d.DomainId, d.Name, d.Weight, counts[i]))
            .ToArray();
    }

    private static void EnsureMinimumOne(int[] counts)
    {
        // Move a seat from the most over-allocated domain to any empty domain until
        // none are empty. Safe because totalItems >= domain count guarantees a donor.
        while (true)
        {
            var zero = Array.FindIndex(counts, c => c == 0);
            if (zero < 0)
            {
                return;
            }

            var donor = 0;
            for (var i = 1; i < counts.Length; i++)
            {
                if (counts[i] > counts[donor])
                {
                    donor = i;
                }
            }

            if (counts[donor] <= 1)
            {
                return;
            }

            counts[donor]--;
            counts[zero]++;
        }
    }
}

/// Selects the concrete items for a mock exam from a candidate pool, honouring
/// the per-domain blueprint and adapting to the learner: weaker concepts (lower
/// mastery) are favoured so the exam probes real gaps. Selection is deterministic
/// for a given seed — reproducible and reasoned about — while varying across
/// users and days through the seed.
public static class MockExamComposer
{
    public static IReadOnlyList<ExamItemRef> Compose(
        IReadOnlyList<ExamItemRef> pool,
        IReadOnlyList<ExamBlueprintDomain> allocation,
        IReadOnlyDictionary<string, double>? masteryByConcept,
        int seed)
    {
        var byDomain = pool
            .GroupBy(i => i.DomainId, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<ExamItemRef>)g.ToArray(), StringComparer.OrdinalIgnoreCase);

        var selected = new List<ExamItemRef>();
        var used = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var domain in allocation)
        {
            if (domain.ItemCount <= 0 || !byDomain.TryGetValue(domain.DomainId, out var candidates))
            {
                continue;
            }

            foreach (var item in Rank(candidates, masteryByConcept, seed).Take(domain.ItemCount))
            {
                if (used.Add(item.ItemId))
                {
                    selected.Add(item);
                }
            }
        }

        // If some domains had fewer candidates than their allocation, backfill from
        // the rest of the pool (still weak-concept-first) to reach the target length.
        var target = allocation.Sum(d => d.ItemCount);
        if (selected.Count < target)
        {
            var leftovers = Rank(pool.Where(i => !used.Contains(i.ItemId)).ToArray(), masteryByConcept, seed);
            foreach (var item in leftovers)
            {
                if (selected.Count >= target)
                {
                    break;
                }

                if (used.Add(item.ItemId))
                {
                    selected.Add(item);
                }
            }
        }

        return selected;
    }

    private static IReadOnlyList<ExamItemRef> Rank(
        IReadOnlyList<ExamItemRef> candidates,
        IReadOnlyDictionary<string, double>? masteryByConcept,
        int seed)
        => candidates
            .OrderByDescending(i => Priority(i, masteryByConcept))
            .ThenBy(i => StableHash(i.ItemId, seed))
            .ThenBy(i => i.ItemId, StringComparer.Ordinal)
            .ToArray();

    private static double Priority(ExamItemRef item, IReadOnlyDictionary<string, double>? masteryByConcept)
    {
        var mastery = masteryByConcept is not null && masteryByConcept.TryGetValue(item.ConceptId, out var m)
            ? Math.Clamp(m, 0, 1)
            : 0; // unseen concept = maximum priority (biggest gap)

        // Weak concepts dominate selection; harder items break ties upward so a
        // weak area is probed with genuinely testing questions, not only recall.
        return ((1 - mastery) * 2) + (item.Difficulty / 3.0);
    }

    private static int StableHash(string value, int seed)
    {
        unchecked
        {
            var hash = 17 + seed;
            foreach (var c in value)
            {
                hash = (hash * 31) + c;
            }

            return hash & 0x7fffffff;
        }
    }
}

/// Grades a mock exam: per-domain accuracy weighted by the *exam* domain weights
/// (not raw item counts) and projected onto Microsoft's familiar 1–1000 scaled
/// score with a 700 pass mark. Domains absent from the submission are dropped and
/// the remaining weights renormalised, so a partial exam still scores fairly.
public static class MockExamScorer
{
    public static ExamScore Score(
        IReadOnlyList<ExamItemRef> items,
        IReadOnlyDictionary<string, bool> correctByItemId,
        IReadOnlyDictionary<string, (string Name, double Weight)> domainMeta,
        int passingScore = 700)
    {
        var graded = items
            .Where(i => correctByItemId.ContainsKey(i.ItemId))
            .ToArray();

        if (graded.Length == 0)
        {
            return new ExamScore(0, 0, false, passingScore, 0, 0, Array.Empty<ExamDomainScore>());
        }

        var domains = graded
            .GroupBy(i => i.DomainId, StringComparer.OrdinalIgnoreCase)
            .Select(g =>
            {
                var total = g.Count();
                var correct = g.Count(i => correctByItemId[i.ItemId]);
                var name = g.Key;
                var weight = 1.0;
                if (domainMeta.TryGetValue(g.Key, out var meta))
                {
                    name = meta.Name;
                    weight = meta.Weight;
                }

                var pct = (int)Math.Round(100d * correct / total);
                return new ExamDomainScore(g.Key, name, weight, correct, total, pct);
            })
            .OrderByDescending(d => d.Weight)
            .ThenBy(d => d.DomainId, StringComparer.Ordinal)
            .ToArray();

        var totalCorrect = graded.Count(i => correctByItemId[i.ItemId]);
        var totalItems = graded.Length;
        var overallPct = (int)Math.Round(100d * totalCorrect / totalItems);

        var weightSum = domains.Sum(d => Math.Max(0, d.Weight));
        var weightedAccuracy = weightSum <= 0
            ? totalCorrect / (double)totalItems
            : domains.Sum(d => Math.Max(0, d.Weight) * (d.Correct / (double)d.Total)) / weightSum;

        var scaled = Math.Clamp((int)Math.Round(1000 * weightedAccuracy), 0, 1000);
        return new ExamScore(scaled, overallPct, scaled >= passingScore, passingScore, totalCorrect, totalItems, domains);
    }
}
