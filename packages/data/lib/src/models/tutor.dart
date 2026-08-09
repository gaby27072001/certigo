/// AI-tutor contracts. The client asks the tutor to explain one answered item;
/// the server returns a grounded, personalised explanation and — because the
/// tutor is a continuously-learning agent — folds the interaction into the
/// learner's model so the next explanation is more personal.
library;

/// Request body for `POST /tutor/explain`.
///
/// Mirrors the backend `TutorExplainRequest`. The userId is never sent — the
/// server derives it from the JWT and keys the per-user learner model on it.
class TutorExplainRequest {
  const TutorExplainRequest({
    required this.trackId,
    required this.lessonId,
    required this.itemId,
    required this.selected,
  });

  final String trackId;
  final String lessonId;
  final String itemId;

  /// The option ids the learner picked for this item.
  final List<String> selected;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trackId': trackId,
    'lessonId': lessonId,
    'itemId': itemId,
    'selected': selected,
  };
}

/// What the tutor learned about this learner for the concept under test, surfaced
/// so the UI can show "you've struggled with this before / great comeback" cues.
///
/// The stats describe history *before* the current answer, so a first consult
/// shows zeroes — the learning shows up on the next visit.
class TutorPersonalization {
  const TutorPersonalization({
    required this.attempts,
    required this.errors,
    required this.accuracyPct,
    required this.recurringStruggle,
    required this.masteredBefore,
    required this.trend,
    this.topConfusedOption,
  });

  final int attempts;
  final int errors;
  final int accuracyPct;

  /// True when this concept keeps tripping the learner up (≥2 errors).
  final bool recurringStruggle;

  /// True when the learner had this concept down before this answer.
  final bool masteredBefore;

  /// One of `steady`, `improving`, `slipping`.
  final String trend;

  /// The learner's signature wrong option for this concept (human label), or
  /// null when there's no clear pattern yet.
  final String? topConfusedOption;

  bool get isImproving => trend == 'improving';
  bool get isSlipping => trend == 'slipping';

  factory TutorPersonalization.fromJson(Map<String, dynamic> json) => TutorPersonalization(
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    errors: (json['errors'] as num?)?.toInt() ?? 0,
    accuracyPct: (json['accuracyPct'] as num?)?.toInt() ?? 0,
    recurringStruggle: json['recurringStruggle'] as bool? ?? false,
    masteredBefore: json['masteredBefore'] as bool? ?? false,
    trend: json['trend'] as String? ?? 'steady',
    topConfusedOption: json['topConfusedOption'] as String?,
  );
}

/// A grounded, personalised tutor explanation for one answered item.
///
/// [source] is `grounded` for the deterministic, free/offline explanation or
/// `ai` for a guardrail-passed LLM upgrade. [recommendation] — the agent's
/// "what to do next" — is always grounded regardless of source.
class TutorExplanation {
  const TutorExplanation({
    required this.itemId,
    required this.conceptId,
    required this.correct,
    required this.headline,
    required this.points,
    required this.encouragement,
    required this.recommendation,
    required this.citedConceptIds,
    required this.source,
    required this.personalization,
  });

  final String itemId;
  final String conceptId;
  final bool correct;

  /// One short, personalised headline (adapts to comebacks / recurring traps).
  final String headline;

  /// 1–4 short teaching points, grounded in the official lesson.
  final List<String> points;
  final String encouragement;

  /// Concrete next step the agent recommends.
  final String recommendation;

  /// The concept ids the explanation is grounded in (a closed, audited set).
  final List<String> citedConceptIds;

  /// `grounded` or `ai`.
  final String source;
  final TutorPersonalization personalization;

  bool get isAiGenerated => source == 'ai';

  factory TutorExplanation.fromJson(Map<String, dynamic> json) => TutorExplanation(
    itemId: json['itemId'] as String? ?? '',
    conceptId: json['conceptId'] as String? ?? '',
    correct: json['correct'] as bool? ?? false,
    headline: json['headline'] as String? ?? '',
    points: (json['points'] as List<dynamic>? ?? <dynamic>[]).map((e) => e as String).toList(),
    encouragement: json['encouragement'] as String? ?? '',
    recommendation: json['recommendation'] as String? ?? '',
    citedConceptIds: (json['citedConceptIds'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e as String)
        .toList(),
    source: json['source'] as String? ?? 'grounded',
    personalization: TutorPersonalization.fromJson(
      json['personalization'] as Map<String, dynamic>? ?? <String, dynamic>{},
    ),
  );
}
