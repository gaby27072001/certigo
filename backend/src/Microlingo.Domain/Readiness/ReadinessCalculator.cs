using Microlingo.Domain.Progress;

namespace Microlingo.Domain.Readiness;

public sealed record DomainReadiness(string DomainId, double Weight, double Coverage, double Mastery, int Score);

public sealed record Readiness(string TrackId, int Score, int Trend7d, IReadOnlyList<DomainReadiness> Domains);

public static class ReadinessCalculator
{
    public static Readiness Compute(
        string trackId,
        IReadOnlyDictionary<string, double> domainWeights,
        IReadOnlyDictionary<string, int> conceptCountsByDomain,
        IEnumerable<ConceptMastery> masteries,
        DateTimeOffset now,
        int trend7d = 0)
    {
        var masteryByDomain = masteries.GroupBy(m => DomainFromConcept(m.ConceptId))
            .ToDictionary(g => g.Key, g => g.ToArray());

        var domains = domainWeights.Select(domain =>
        {
            var domainId = domain.Key;
            var totalConcepts = Math.Max(1, conceptCountsByDomain.GetValueOrDefault(domainId, 0));
            var items = masteryByDomain.GetValueOrDefault(domainId, Array.Empty<ConceptMastery>());
            var coverage = Clamp(items.Length / (double)totalConcepts, 0, 1);
            var mastery = items.Length == 0 ? 0 : Clamp(items.Average(m => m.MasteryScore), 0, 1);
            var recency = items.Length == 0 ? 0 : Clamp(items.Average(m => Recency(m, now)), 0, 1);

            // Readiness intentionally rewards breadth first: coverage^0.5 makes missing exam
            // areas visible while mastery and recency keep stale memorization from over-scoring.
            var score = (int)Math.Round(100 * Math.Pow(coverage, 0.5) * mastery * Math.Pow(recency, 0.3));
            return new DomainReadiness(domainId, domain.Value, coverage, mastery, score);
        }).ToArray();

        var totalWeight = Math.Max(0.0001, domains.Sum(d => d.Weight));
        var weighted = domains.Sum(d => d.Score * d.Weight) / totalWeight;
        return new Readiness(trackId, (int)Math.Round(weighted), trend7d, domains);
    }

    private static double Recency(ConceptMastery m, DateTimeOffset now)
    {
        var days = Math.Max(0, (now - m.LastReviewedAt).TotalDays);
        return Math.Exp(-days / 30);
    }

    private static string DomainFromConcept(string conceptId)
    {
        var split = conceptId.Split(':', StringSplitOptions.RemoveEmptyEntries);
        return split.Length > 1 ? split[0] : "default";
    }

    private static double Clamp(double value, double min, double max) => Math.Min(max, Math.Max(min, value));
}
