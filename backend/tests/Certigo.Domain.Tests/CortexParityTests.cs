using System.Text.Json;
using Certigo.Domain.Progress;
using Certigo.Domain.Readiness;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

/// <summary>
/// Data-driven Cortex parity golden tests.
///
/// The <c>parity</c> vectors are the single source of truth shared with the
/// Flutter client (<c>packages/cortex/test/cortex_golden_test.dart</c>): the exact
/// same JSON (<c>packages/cortex/test/golden/cortex_golden_vectors.json</c>) is
/// asserted on both sides, and the <c>ci-cortex-parity</c> workflow fails if the
/// Dart and .NET implementations diverge. The <c>cortexOnly</c> vectors cover the
/// SessionPlanner, which has no .NET twin, so only Dart asserts them.
/// </summary>
public sealed class CortexParityTests
{
    private static readonly DateTimeOffset Now = new(2025, 1, 1, 0, 0, 0, TimeSpan.Zero);

    // Kept alive for the process lifetime so callers can read RootElement lazily.
    private static readonly JsonDocument Doc = LoadVectors();

    private static JsonElement Vectors => Doc.RootElement;

    private static JsonElement Parity => Vectors.GetProperty("parity");

    [Fact]
    public void Algo_version_matches_the_shared_golden_vector()
    {
        CortexAlgo.Version.Should().Be(Vectors.GetProperty("algoVersion").GetString());
    }

    [Fact]
    public void Scheduler_matches_the_shared_golden_vectors()
    {
        foreach (var v in Parity.GetProperty("scheduler").EnumerateArray())
        {
            var name = v.GetProperty("name").GetString()!;

            var m = ConceptMastery.New("user-1", "t", "c");
            foreach (var g in v.GetProperty("grades").EnumerateArray())
            {
                m = ReviewScheduler.Apply(m, GradeFromName(g.GetString()!), Now);
            }

            var expected = v.GetProperty("expected");
            var stability = expected.GetProperty("stability").GetDouble();
            m.Stability.Should().BeApproximately(stability, 1e-9, "stability [{0}]", name);
            m.Difficulty.Should()
                .BeApproximately(expected.GetProperty("difficulty").GetDouble(), 1e-9, "difficulty [{0}]", name);
            m.Reps.Should().Be(expected.GetProperty("reps").GetInt32(), "reps [{0}]", name);
            m.Lapses.Should().Be(expected.GetProperty("lapses").GetInt32(), "lapses [{0}]", name);
            // Mastery is derived from stability; pin it the same way both sides do.
            m.MasteryScore.Should()
                .BeApproximately(1 - Math.Exp(-stability / 20), 1e-9, "mastery [{0}]", name);

            if (v.GetProperty("checkDueAt").GetBoolean())
            {
                // Fractional-day scheduling: DueAt == now + stability days. Tolerance
                // (1ms) absorbs cross-language float rounding while still ruling out
                // whole-day ceil() drift.
                var offsetSeconds = v.GetProperty("dueAtOffsetSeconds").GetDouble();
                (m.DueAt - Now).TotalSeconds.Should()
                    .BeApproximately(offsetSeconds, 1e-3, "dueAt [{0}]", name);
            }
        }
    }

    [Fact]
    public void Weakness_matches_the_shared_golden_vectors()
    {
        foreach (var v in Parity.GetProperty("weakness").EnumerateArray())
        {
            var name = v.GetProperty("name").GetString()!;

            var m = ConceptMastery.New("user-1", "t", "c") with
            {
                Reps = v.GetProperty("reps").GetInt32(),
                MasteryScore = v.GetProperty("masteryScore").GetDouble(),
            };

            m.IsWeak.Should().Be(v.GetProperty("expectedIsWeak").GetBoolean(), "isWeak [{0}]", name);
        }
    }

    [Fact]
    public void Readiness_matches_the_shared_golden_vectors()
    {
        foreach (var v in Parity.GetProperty("readiness").EnumerateArray())
        {
            var name = v.GetProperty("name").GetString()!;
            var trackId = v.GetProperty("trackId").GetString()!;

            var domainWeights = new Dictionary<string, double>();
            var conceptCountsByDomain = new Dictionary<string, int>();
            foreach (var d in v.GetProperty("domains").EnumerateArray())
            {
                var domainId = d.GetProperty("domainId").GetString()!;
                domainWeights[domainId] = d.GetProperty("weight").GetDouble();
                conceptCountsByDomain[domainId] = d.GetProperty("conceptsInDomain").GetInt32();
            }

            // JSON concept ids ("c", "a1", ...) carry no "domain:concept" separator,
            // so the explicit conceptId -> domainId map is what pins each mastery to
            // its domain (identical to how the Dart test groups masteries).
            var conceptDomains = new Dictionary<string, string>();
            var masteries = new List<ConceptMastery>();
            foreach (var mv in v.GetProperty("masteries").EnumerateArray())
            {
                var conceptId = mv.GetProperty("conceptId").GetString()!;
                var domainId = mv.GetProperty("domainId").GetString()!;
                conceptDomains[conceptId] = domainId;
                masteries.Add(ConceptMastery.New("user-1", trackId, conceptId) with
                {
                    MasteryScore = mv.GetProperty("masteryScore").GetDouble(),
                    Reps = mv.GetProperty("reps").GetInt32(),
                    LastReviewedAt = Now.AddDays(-mv.GetProperty("lastReviewedAtOffsetDays").GetDouble()),
                });
            }

            var readiness = ReadinessCalculator.Compute(
                trackId,
                domainWeights,
                conceptCountsByDomain,
                masteries,
                Now,
                conceptDomains: conceptDomains);

            foreach (var expectedDomain in v.GetProperty("expectedDomainScores").EnumerateObject())
            {
                var domainId = expectedDomain.Name;
                var expectedScore = expectedDomain.Value.GetInt32();
                readiness.Domains.Single(d => d.DomainId == domainId).Score.Should()
                    .Be(expectedScore, "domain {0} [{1}]", domainId, name);
            }

            readiness.Score.Should()
                .Be(v.GetProperty("expectedTrackScore").GetInt32(), "track [{0}]", name);
        }
    }

    private static ReviewGrade GradeFromName(string name) => name switch
    {
        "again" => ReviewGrade.Again,
        "hard" => ReviewGrade.Hard,
        "good" => ReviewGrade.Good,
        "easy" => ReviewGrade.Easy,
        _ => throw new ArgumentOutOfRangeException(nameof(name), name, "unknown grade"),
    };

    private static JsonDocument LoadVectors()
    {
        var dir = AppContext.BaseDirectory;
        while (dir is not null)
        {
            var candidate = Path.Combine(
                dir, "packages", "cortex", "test", "golden", "cortex_golden_vectors.json");
            if (File.Exists(candidate))
            {
                return JsonDocument.Parse(File.ReadAllText(candidate));
            }

            dir = Directory.GetParent(dir)?.FullName;
        }

        throw new InvalidOperationException(
            $"cortex_golden_vectors.json not found walking up from {AppContext.BaseDirectory}");
    }
}
