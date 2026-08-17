/// A lightweight summary of one certification track, for the course picker.
///
/// The catalog endpoint (`GET /catalog/tracks`) returns one of these per track
/// so the learner can browse and switch between the certifications the app
/// offers — Duolingo-style — without loading each full [LearningPath].
library;

class TrackSummary {
  const TrackSummary({
    required this.id,
    required this.code,
    required this.title,
    required this.level,
    required this.summary,
    required this.unitCount,
    required this.lessonCount,
    this.domains = const <CertificationDomain>[],
    this.prerequisites = '',
    this.studyGuideUrl = '',
    this.examUrl = '',
    this.blueprintDate = '',
    this.lifecycle = '',
    this.lifecycleNote = '',
    this.examDetailsNote = '',
    this.learningAvailable = true,
    this.replacementCode = '',
    this.migrationNote = '',
  });

  /// Stable track id, e.g. "az-900" — the key consumed by `pathProvider`.
  final String id;

  /// Official exam code, e.g. "AZ-900".
  final String code;

  /// Official certification title (kept in Microsoft's English wording).
  final String title;

  /// Authoring level: "fundamentals", "associate", "expert" (may be empty).
  final String level;

  /// One-line French description of what the track covers.
  final String summary;

  /// Number of units (chapters) on the track.
  final int unitCount;

  /// Total number of lessons across all units.
  final int lessonCount;

  /// Official skills-at-a-glance domains and their percentage ranges.
  final List<CertificationDomain> domains;

  /// Official audience prerequisites or recommended prior experience.
  final String prerequisites;

  final String studyGuideUrl;
  final String examUrl;

  /// ISO-8601 date of the official skills blueprint consumed by the catalogue.
  final String blueprintDate;

  /// Exam lifecycle (`active` or `retired`) when official metadata is available.
  final String lifecycle;
  final String lifecycleNote;

  /// Scheduling caveat for details that Microsoft can change.
  final String examDetailsNote;

  /// Whether the Certigo learning path exists and can be opened.
  final bool learningAvailable;

  /// Official successor code for a retired exam, when one exists.
  final String replacementCode;

  /// Product-level guidance that preserves historical progress during replacement.
  final String migrationNote;

  bool get isRetired => lifecycle == 'retired';

  factory TrackSummary.fromJson(Map<String, dynamic> json) => TrackSummary(
        id: json['id'] as String,
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        level: json['level'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        unitCount: (json['unitCount'] as num?)?.toInt() ?? 0,
        lessonCount: (json['lessonCount'] as num?)?.toInt() ?? 0,
        domains: (json['domains'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => CertificationDomain.fromJson(value as Map<String, dynamic>))
            .toList(growable: false),
        prerequisites: json['prerequisites'] as String? ?? '',
        studyGuideUrl: json['studyGuideUrl'] as String? ?? '',
        examUrl: json['examUrl'] as String? ?? '',
        blueprintDate: json['blueprintDate'] as String? ?? '',
        lifecycle: json['lifecycle'] as String? ?? '',
        lifecycleNote: json['lifecycleNote'] as String? ?? '',
        examDetailsNote: json['examDetailsNote'] as String? ?? '',
        learningAvailable: json['learningAvailable'] as bool? ?? true,
        replacementCode: json['replacementCode'] as String? ?? '',
        migrationNote: json['migrationNote'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'title': title,
        'level': level,
        'summary': summary,
        'unitCount': unitCount,
        'lessonCount': lessonCount,
        'domains': domains.map((CertificationDomain domain) => domain.toJson()).toList(),
        'prerequisites': prerequisites,
        'studyGuideUrl': studyGuideUrl,
        'examUrl': examUrl,
        'blueprintDate': blueprintDate,
        'lifecycle': lifecycle,
        'lifecycleNote': lifecycleNote,
        'examDetailsNote': examDetailsNote,
        'learningAvailable': learningAvailable,
        'replacementCode': replacementCode,
        'migrationNote': migrationNote,
      };
}

class CertificationDomain {
  const CertificationDomain({
    required this.id,
    required this.name,
    required this.minWeightPct,
    required this.maxWeightPct,
  });

  final String id;
  final String name;
  final int minWeightPct;
  final int maxWeightPct;

  String get weightLabel =>
      minWeightPct == maxWeightPct ? '$minWeightPct%' : '$minWeightPct–$maxWeightPct%';

  factory CertificationDomain.fromJson(Map<String, dynamic> json) => CertificationDomain(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        minWeightPct: (json['minWeightPct'] as num?)?.toInt() ?? 0,
        maxWeightPct: (json['maxWeightPct'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'minWeightPct': minWeightPct,
        'maxWeightPct': maxWeightPct,
      };
}
