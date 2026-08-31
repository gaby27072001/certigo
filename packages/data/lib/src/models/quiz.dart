/// Quiz submission contracts. The client sends the learner's raw answers; the
/// server scores them authoritatively and returns per-item explanations,
/// rewards and the concepts that still need work.
library;

import 'lesson.dart' show ItemType, itemTypeToWire;

/// One answered item in a submission.
class QuizAnswer {
  const QuizAnswer({
    required this.itemId,
    required this.type,
    required this.selected,
    required this.latencyMs,
  });

  final String itemId;
  final ItemType type;

  /// Selected option ids (single for mcq, many for multi/ordering/match).
  final List<String> selected;

  /// Time from item shown to answer locked — feeds Cortex grading.
  final int latencyMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'itemId': itemId,
        'itemType': itemTypeToWire(type),
        'selected': selected,
        'latencyMs': latencyMs,
      };
}

/// Request body for `POST /quiz/{lessonId}/submit`.
///
/// [clientAttemptId] makes submission idempotent — retries never double-count
/// XP or corrupt mastery state.
class SubmitQuizRequest {
  const SubmitQuizRequest({
    required this.clientAttemptId,
    required this.trackId,
    required this.startedAt,
    required this.answers,
    this.publicManifestId,
  });

  final String clientAttemptId;
  final String trackId;
  final DateTime startedAt;
  final List<QuizAnswer> answers;
  final String? publicManifestId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientAttemptId': clientAttemptId,
        'trackId': trackId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'answers': answers.map((a) => a.toJson()).toList(),
        if (publicManifestId != null) 'publicManifestId': publicManifestId,
      };
}

/// Server-graded result of a quiz submission.
class SubmitQuizResult {
  const SubmitQuizResult({
    required this.attemptId,
    required this.scorePct,
    required this.results,
    required this.rewards,
    required this.weakConcepts,
    this.nextReviewDueAt,
  });

  final String attemptId;
  final int scorePct;
  final List<ItemResult> results;
  final QuizRewards rewards;

  /// Concept ids the learner should revisit (mastery still < 0.5).
  final List<String> weakConcepts;
  final DateTime? nextReviewDueAt;

  factory SubmitQuizResult.fromJson(Map<String, dynamic> json) => SubmitQuizResult(
        attemptId: json['attemptId'] as String,
        scorePct: (json['scorePct'] as num?)?.toInt() ?? 0,
        results: (json['results'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => ItemResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        rewards:
            QuizRewards.fromJson(json['rewards'] as Map<String, dynamic>? ?? <String, dynamic>{}),
        weakConcepts: (json['weakConcepts'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e as String)
            .toList(),
        nextReviewDueAt: json['nextReviewDueAt'] == null
            ? null
            : DateTime.parse(json['nextReviewDueAt'] as String),
      );
}

/// Per-item grading + the explanatory feedback that powers real learning.
class ItemResult {
  const ItemResult({
    required this.itemId,
    required this.conceptId,
    required this.correct,
    required this.correctAnswer,
    required this.explanation,
    required this.masteryDelta,
  });

  final String itemId;
  final String conceptId;
  final bool correct;

  /// The correct option ids — revealed AFTER answering, for comprehension.
  final List<String> correctAnswer;

  /// Why the answer is right/wrong (markdown). Never empty.
  final String explanation;
  final double masteryDelta;

  factory ItemResult.fromJson(Map<String, dynamic> json) => ItemResult(
        itemId: json['itemId'] as String,
        conceptId: json['conceptId'] as String? ?? '',
        correct: json['correct'] as bool? ?? false,
        correctAnswer: (json['correctAnswer'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e as String)
            .toList(),
        explanation: json['explanation'] as String? ?? '',
        masteryDelta: (json['masteryDelta'] as num?)?.toDouble() ?? 0,
      );
}

class QuizRewards {
  const QuizRewards({
    required this.xpEarned,
    required this.newXp,
    required this.levelUp,
    required this.streakExtended,
    required this.gemsEarned,
    required this.achievementsUnlocked,
  });

  final int xpEarned;
  final int newXp;
  final bool levelUp;
  final bool streakExtended;

  /// Gems credited for this attempt (perfect-score and streak bonuses).
  final int gemsEarned;
  final List<String> achievementsUnlocked;

  factory QuizRewards.fromJson(Map<String, dynamic> json) => QuizRewards(
        xpEarned: (json['xpEarned'] as num?)?.toInt() ?? 0,
        newXp: (json['newXp'] as num?)?.toInt() ?? 0,
        levelUp: json['levelUp'] as bool? ?? false,
        streakExtended: json['streakExtended'] as bool? ?? false,
        gemsEarned: (json['gemsEarned'] as num?)?.toInt() ?? 0,
        achievementsUnlocked: (json['achievementsUnlocked'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e as String)
            .toList(),
      );
}
