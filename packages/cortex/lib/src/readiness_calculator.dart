import 'dart:math' as math;
import 'concept_mastery.dart';

/// Readiness math — turns per-concept mastery into the product's North-Star
/// **Readiness Score** (0–100 per track), broken down by exam domain.
///
/// Formula per domain:
///   score = 100 · coverage^0.5 · mastery^1.0 · recency^0.3
/// then the track score is the exam-weighted sum of domain scores. Exponents
/// are tuned so that breadth (coverage) and freshness (recency) both matter but
/// genuine mastery dominates — you can't reach 100 by skimming everything once.
class ReadinessCalculator {
  const ReadinessCalculator._();

  static const double _coverageExp = 0.5;
  static const double _masteryExp = 1.0;
  static const double _recencyExp = 0.3;

  /// Compute the readiness for one domain.
  ///
  /// [conceptsInDomain] total concepts authored for the domain (denominator for
  /// coverage); [masteries] the user's states for concepts they've touched.
  static DomainReadiness domain({
    required String domainId,
    required double weight,
    required int conceptsInDomain,
    required List<ConceptMastery> masteries,
    required DateTime now,
  }) {
    if (conceptsInDomain <= 0) {
      return DomainReadiness(domainId: domainId, weight: weight, coverage: 0, mastery: 0, score: 0);
    }

    final double coverage = (masteries.length / conceptsInDomain).clamp(0.0, 1.0);

    final double avgMastery = masteries.isEmpty
        ? 0
        : masteries.map((ConceptMastery m) => m.masteryScore).reduce((a, b) => a + b) /
            masteries.length;

    final double recency = masteries.isEmpty
        ? 0
        : masteries.map((ConceptMastery m) => _recencyWeight(m, now)).reduce((a, b) => a + b) /
            masteries.length;

    final num raw = 100 *
        math.pow(coverage, _coverageExp) *
        math.pow(avgMastery, _masteryExp) *
        math.pow(recency, _recencyExp);

    return DomainReadiness(
      domainId: domainId,
      weight: weight,
      coverage: coverage,
      mastery: avgMastery,
      score: raw.round(),
    );
  }

  /// Weighted roll-up across domains → the track Readiness Score.
  static int track(List<DomainReadiness> domains) {
    if (domains.isEmpty) return 0;
    final double totalWeight = domains.map((DomainReadiness d) => d.weight).reduce((a, b) => a + b);
    if (totalWeight <= 0) return 0;
    final double weighted =
        domains.map((DomainReadiness d) => d.score * d.weight).reduce((a, b) => a + b);
    return (weighted / totalWeight).round();
  }

  /// Recency decays from 1 to ~0 over ~30 days since last review. Uses fractional
  /// days (not truncated) so it matches the backend's `TotalDays`-based decay.
  static double _recencyWeight(ConceptMastery m, DateTime now) {
    final double days =
        (now.difference(m.lastReviewedAt).inMicroseconds / Duration.microsecondsPerDay)
            .clamp(0.0, double.infinity);
    return math.exp(-days / 30).clamp(0.0, 1.0);
  }
}

/// Readiness breakdown for a single exam domain.
class DomainReadiness {
  const DomainReadiness({
    required this.domainId,
    required this.weight,
    required this.coverage,
    required this.mastery,
    required this.score,
  });

  final String domainId;
  final double weight;
  final double coverage; // 0..1
  final double mastery; // 0..1
  final int score; // 0..100
}
