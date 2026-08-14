import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// Aggregated data for the Home surface: the learner's profile (top bar + daily
/// goal) and their active-track path (readiness + what to do next).
class HomeData {
  const HomeData({required this.profile, required this.path});

  final UserProfile profile;
  final LearningPath path;

  /// The next lesson to resume: the first in-progress or available node,
  /// scanning units top-to-bottom. Null once everything is completed/mastered.
  PathLesson? get nextLesson {
    for (final PathUnit unit in path.units) {
      for (final PathLesson lesson in unit.lessons) {
        if (lesson.status == NodeStatus.inProgress || lesson.status == NodeStatus.available) {
          return lesson;
        }
      }
    }
    return null;
  }

  /// The unit that owns [nextLesson], used for a contextual subtitle.
  PathUnit? get nextUnit {
    final PathLesson? target = nextLesson;
    if (target == null) {
      return null;
    }
    for (final PathUnit unit in path.units) {
      if (unit.lessons.any((PathLesson l) => l.id == target.id)) {
        return unit;
      }
    }
    return null;
  }

  /// The weakest exam domain by score — the highest-leverage place to revise.
  DomainProgress? get weakestDomain {
    if (path.domains.isEmpty) {
      return null;
    }
    return path.domains.reduce((DomainProgress a, DomainProgress b) => a.score <= b.score ? a : b);
  }
}

/// Loads [HomeData] by composing the shared profile + path providers, keyed off
/// the profile's active track (falls back to AZ-900 for fresh accounts).
final homeDataProvider = FutureProvider.autoDispose<HomeData>((Ref ref) async {
  final UserProfile profile = await ref.watch(meProvider.future);
  final String trackId = profile.activeTrackId ?? 'az-900';
  final LearningPath path = await ref.watch(pathProvider(trackId).future);
  return HomeData(profile: profile, path: path);
});
