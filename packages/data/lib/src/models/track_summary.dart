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
    this.provider = 'microsoft',
    this.retiringOn,
  });

  /// Stable track id, e.g. "az-900" — the key consumed by `pathProvider`.
  final String id;

  /// Official exam code, e.g. "AZ-900".
  final String code;

  /// Official certification title (kept in the vendor's English wording).
  final String title;

  /// Authoring level: "fundamentals", "associate", "professional",
  /// "specialty", "expert", "master" (may be empty).
  final String level;

  /// One-line French description of what the track covers.
  final String summary;

  /// Number of units (chapters) on the track.
  final int unitCount;

  /// Total number of lessons across all units.
  final int lessonCount;

  /// Certification vendor: "microsoft", "aws", "google", "oracle",
  /// "anthropic", "openai". Defaults to "microsoft" for legacy payloads.
  final String provider;

  /// Optional retirement date (ISO-8601 string) when the exam is sunsetting.
  final String? retiringOn;

  factory TrackSummary.fromJson(Map<String, dynamic> json) => TrackSummary(
        id: json['id'] as String,
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        level: json['level'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        unitCount: (json['unitCount'] as num?)?.toInt() ?? 0,
        lessonCount: (json['lessonCount'] as num?)?.toInt() ?? 0,
        provider: (json['provider'] as String?)?.isNotEmpty == true
            ? json['provider'] as String
            : 'microsoft',
        retiringOn: json['retiringOn'] as String?,
      );
}
