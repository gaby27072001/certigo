/// A learner's path through one certification track, with per-unit progress and
/// the track Readiness Score. Rendered by the Path screen.
library;

class LearningPath {
  const LearningPath({
    required this.trackId,
    required this.trackName,
    required this.exam,
    required this.readinessScore,
    required this.readinessTrend7d,
    required this.units,
    required this.domains,
  });

  final String trackId;
  final String trackName;

  /// e.g. "AZ-900".
  final String exam;

  /// 0–100 North-Star readiness for this track.
  final int readinessScore;
  final int readinessTrend7d;
  final List<PathUnit> units;
  final List<DomainProgress> domains;

  factory LearningPath.fromJson(Map<String, dynamic> json) => LearningPath(
        trackId: json['trackId'] as String,
        trackName: json['trackName'] as String? ?? '',
        exam: json['exam'] as String? ?? '',
        readinessScore: (json['readinessScore'] as num?)?.toInt() ?? 0,
        readinessTrend7d: (json['readinessTrend7d'] as num?)?.toInt() ?? 0,
        units: (json['units'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => PathUnit.fromJson(e as Map<String, dynamic>))
            .toList(),
        domains: (json['domains'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => DomainProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Lifecycle state of a unit/lesson node on the path.
enum NodeStatus { locked, available, inProgress, completed, mastered }

NodeStatus _statusFrom(String? raw) => switch (raw) {
      'available' => NodeStatus.available,
      'inProgress' => NodeStatus.inProgress,
      'completed' => NodeStatus.completed,
      'mastered' => NodeStatus.mastered,
      _ => NodeStatus.locked,
    };

class PathUnit {
  const PathUnit({
    required this.id,
    required this.title,
    required this.domainId,
    required this.status,
    required this.lessons,
  });

  final String id;
  final String title;
  final String domainId;
  final NodeStatus status;
  final List<PathLesson> lessons;

  int get completedCount => lessons
      .where((l) => l.status == NodeStatus.completed || l.status == NodeStatus.mastered)
      .length;

  factory PathUnit.fromJson(Map<String, dynamic> json) => PathUnit(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        domainId: json['domainId'] as String? ?? '',
        status: _statusFrom(json['status'] as String?),
        lessons: (json['lessons'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => PathLesson.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PathLesson {
  const PathLesson({
    required this.id,
    required this.title,
    required this.status,
    required this.estMinutes,
    required this.masteryPct,
  });

  final String id;
  final String title;
  final NodeStatus status;
  final int estMinutes;
  final int masteryPct;

  factory PathLesson.fromJson(Map<String, dynamic> json) => PathLesson(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        status: _statusFrom(json['status'] as String?),
        estMinutes: (json['estMinutes'] as num?)?.toInt() ?? 5,
        masteryPct: (json['masteryPct'] as num?)?.toInt() ?? 0,
      );
}

class DomainProgress {
  const DomainProgress({
    required this.id,
    required this.name,
    required this.weight,
    required this.score,
  });

  final String id;
  final String name;
  final double weight;
  final int score;

  factory DomainProgress.fromJson(Map<String, dynamic> json) => DomainProgress(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        score: (json['score'] as num?)?.toInt() ?? 0,
      );
}
