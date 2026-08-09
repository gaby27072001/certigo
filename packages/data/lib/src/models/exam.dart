/// Mock exam (adaptive practice exam). The client requests a blueprint-weighted
/// exam, runs it like a quiz (reusing [QuizAnswer]/[QuizOption]), then submits
/// all answers at once for authoritative, domain-scored server grading.
library;

import 'lesson.dart' show ItemType, QuizOption, itemTypeFrom;
import 'quiz.dart' show ItemResult, QuizAnswer, QuizRewards;

/// Request body for `POST /exam/generate`. [length] is optional — omit it to let
/// the server pick the blueprint's default exam length.
class MockExamRequest {
  const MockExamRequest({required this.trackId, this.length});

  final String trackId;
  final int? length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trackId': trackId,
    if (length != null) 'length': length,
  };
}

/// A *public*, answer-free exam item: stem + options come from a lesson's public
/// check; the correct answer stays server-side in the answer key.
class MockExamItem {
  const MockExamItem({
    required this.itemId,
    required this.lessonId,
    required this.domainId,
    required this.type,
    required this.stem,
    required this.options,
  });

  final String itemId;
  final String lessonId;
  final String domainId;
  final ItemType type;
  final String stem;
  final List<QuizOption> options;

  factory MockExamItem.fromJson(Map<String, dynamic> json) => MockExamItem(
    itemId: json['itemId'] as String,
    lessonId: json['lessonId'] as String? ?? '',
    domainId: json['domainId'] as String? ?? '',
    type: itemTypeFrom(json['type'] as String?),
    stem: json['stem'] as String? ?? '',
    options: (json['options'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// One row of the exam blueprint: how many items a domain contributes and its
/// weight toward the scaled score.
class MockExamBlueprintDomain {
  const MockExamBlueprintDomain({
    required this.domainId,
    required this.name,
    required this.weight,
    required this.itemCount,
  });

  final String domainId;
  final String name;
  final double weight;
  final int itemCount;

  factory MockExamBlueprintDomain.fromJson(Map<String, dynamic> json) => MockExamBlueprintDomain(
    domainId: json['domainId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
  );
}

/// A generated mock exam: blueprint + the ordered, answer-free items to run.
class MockExam {
  const MockExam({
    required this.examId,
    required this.trackId,
    required this.trackCode,
    required this.trackTitle,
    required this.timeLimitSeconds,
    required this.passingScore,
    required this.blueprint,
    required this.items,
  });

  final String examId;
  final String trackId;
  final String trackCode;
  final String trackTitle;
  final int timeLimitSeconds;
  final int passingScore;
  final List<MockExamBlueprintDomain> blueprint;
  final List<MockExamItem> items;

  factory MockExam.fromJson(Map<String, dynamic> json) => MockExam(
    examId: json['examId'] as String,
    trackId: json['trackId'] as String? ?? '',
    trackCode: json['trackCode'] as String? ?? '',
    trackTitle: json['trackTitle'] as String? ?? '',
    timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt() ?? 0,
    passingScore: (json['passingScore'] as num?)?.toInt() ?? 0,
    blueprint: (json['blueprint'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => MockExamBlueprintDomain.fromJson(e as Map<String, dynamic>))
        .toList(),
    items: (json['items'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => MockExamItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Request body for `POST /exam/submit`. [clientAttemptId] makes submission
/// idempotent; [answers] reuses the quiz [QuizAnswer] wire shape.
class SubmitMockExamRequest {
  const SubmitMockExamRequest({
    required this.clientAttemptId,
    required this.trackId,
    required this.examId,
    required this.startedAt,
    required this.answers,
  });

  final String clientAttemptId;
  final String trackId;
  final String examId;
  final DateTime startedAt;
  final List<QuizAnswer> answers;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientAttemptId': clientAttemptId,
    'trackId': trackId,
    'examId': examId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'answers': answers.map((a) => a.toJson()).toList(),
  };
}

/// Per-domain breakdown of an exam result.
class ExamDomainScore {
  const ExamDomainScore({
    required this.domainId,
    required this.name,
    required this.weight,
    required this.correct,
    required this.total,
    required this.pct,
  });

  final String domainId;
  final String name;
  final double weight;
  final int correct;
  final int total;
  final int pct;

  factory ExamDomainScore.fromJson(Map<String, dynamic> json) => ExamDomainScore(
    domainId: json['domainId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    pct: (json['pct'] as num?)?.toInt() ?? 0,
  );
}

/// Server-graded result of a mock exam: scaled score, pass/fail, per-domain
/// breakdown, per-item feedback ([ItemResult]) and the earned [QuizRewards].
class MockExamResult {
  const MockExamResult({
    required this.attemptId,
    required this.examId,
    required this.scaledScore,
    required this.pct,
    required this.passed,
    required this.passingScore,
    required this.correct,
    required this.total,
    required this.domains,
    required this.results,
    required this.rewards,
    required this.weakConcepts,
  });

  final String attemptId;
  final String examId;
  final int scaledScore;
  final int pct;
  final bool passed;
  final int passingScore;
  final int correct;
  final int total;
  final List<ExamDomainScore> domains;
  final List<ItemResult> results;
  final QuizRewards rewards;
  final List<String> weakConcepts;

  factory MockExamResult.fromJson(Map<String, dynamic> json) => MockExamResult(
    attemptId: json['attemptId'] as String? ?? '',
    examId: json['examId'] as String? ?? '',
    scaledScore: (json['scaledScore'] as num?)?.toInt() ?? 0,
    pct: (json['pct'] as num?)?.toInt() ?? 0,
    passed: json['passed'] as bool? ?? false,
    passingScore: (json['passingScore'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    domains: (json['domains'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ExamDomainScore.fromJson(e as Map<String, dynamic>))
        .toList(),
    results: (json['results'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ItemResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    rewards: QuizRewards.fromJson(json['rewards'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    weakConcepts: (json['weakConcepts'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e as String)
        .toList(),
  );
}
