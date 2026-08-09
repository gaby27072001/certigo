library;

/// The "next best action" coach for one certification track.
///
/// Mirrors the backend `NextBestDto`: a server-ranked list of what the learner
/// should do *right now* to raise readiness, fusing forgetting risk (FSRS),
/// active struggles and the skill-path frontier. The client renders [items] as
/// an ordered shelf of cards; [top] is the single highest-leverage action.
class NextBest {
  const NextBest({required this.trackId, required this.generatedAt, required this.items});

  final String trackId;
  final DateTime generatedAt;
  final List<Recommendation> items;

  /// True when the coach has nothing to suggest (e.g. unknown track).
  bool get isEmpty => items.isEmpty;

  /// The single most important action, or null when [items] is empty.
  Recommendation? get top => items.isEmpty ? null : items.first;

  factory NextBest.fromJson(Map<String, dynamic> json) {
    return NextBest(
      trackId: json['trackId'] as String? ?? '',
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Recommendation.fromJson)
          .toList(),
    );
  }
}

/// The kind of action the coach recommends, parsed from the wire string.
///
/// * [practice] — drill a concept the learner is actively struggling with.
/// * [review]   — revisit a concept whose memory is decaying (FSRS due).
/// * [resume]   — finish an in-progress lesson at the path frontier.
/// * [start]    — begin the next available lesson (the default/fallback).
enum RecommendationKind { practice, review, resume, start }

RecommendationKind _kindFrom(String? raw) {
  return switch (raw) {
    'practice' => RecommendationKind.practice,
    'review' => RecommendationKind.review,
    'resume' => RecommendationKind.resume,
    _ => RecommendationKind.start,
  };
}

/// One coach card. Mirrors the backend `RecommendationItemDto`.
///
/// [reason] is a short, already-localised (French) sentence from the server, so
/// the UI never re-derives copy. [priority], [masteryPct] and
/// [forgettingRiskPct] are 0–100 integers the UI can show as urgency without
/// recomputing anything. [lessonId]/[unitId]/[conceptId] may be null depending
/// on [kind] (a concept-level review can lack a lesson home).
class Recommendation {
  const Recommendation({
    required this.kind,
    required this.lessonId,
    required this.unitId,
    required this.conceptId,
    required this.title,
    required this.domainId,
    required this.domainName,
    required this.reason,
    required this.estMinutes,
    required this.priority,
    required this.masteryPct,
    required this.forgettingRiskPct,
  });

  final RecommendationKind kind;
  final String? lessonId;
  final String? unitId;
  final String? conceptId;
  final String title;
  final String domainId;
  final String domainName;
  final String reason;
  final int estMinutes;
  final int priority;
  final int masteryPct;
  final int forgettingRiskPct;

  /// True when the coach can open a concrete lesson for this action.
  bool get hasLesson => (lessonId?.isNotEmpty ?? false);

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      kind: _kindFrom(json['kind'] as String?),
      lessonId: json['lessonId'] as String?,
      unitId: json['unitId'] as String?,
      conceptId: json['conceptId'] as String?,
      title: json['title'] as String? ?? '',
      domainId: json['domainId'] as String? ?? '',
      domainName: json['domainName'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      estMinutes: (json['estMinutes'] as num?)?.toInt() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      masteryPct: (json['masteryPct'] as num?)?.toInt() ?? 0,
      forgettingRiskPct: (json['forgettingRiskPct'] as num?)?.toInt() ?? 0,
    );
  }
}
