import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// Aggregated data for the Home surface: the learner's profile (top bar + daily
/// goal) and their active-track path (readiness + what to do next).
class HomeData {
  const HomeData({required this.profile, required this.path});

  final UserProfile profile;
  final LearningPath path;

  PathLesson? get nextLesson => path.nextLesson;

  PathUnit? get nextUnit => path.nextUnit;

  DomainProgress? get weakestDomain => path.weakestDomain;
}

/// Home's reading of a path: what to resume, and what to reinforce.
///
/// These live on [LearningPath] rather than on [HomeData] so the Home surface
/// can render the track-scoped band from a path alone, without also requiring
/// the profile to have loaded.
extension HomePathInsights on LearningPath {
  /// The next lesson to resume: the first in-progress or available node,
  /// scanning units top-to-bottom. Null once everything is completed/mastered.
  PathLesson? get nextLesson {
    for (final PathUnit unit in units) {
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
    for (final PathUnit unit in units) {
      if (unit.lessons.any((PathLesson l) => l.id == target.id)) {
        return unit;
      }
    }
    return null;
  }

  /// The weakest exam domain by score — the highest-leverage place to revise.
  DomainProgress? get weakestDomain {
    if (domains.isEmpty) {
      return null;
    }
    return domains.reduce((DomainProgress a, DomainProgress b) => a.score <= b.score ? a : b);
  }
}

/// Loads [HomeData] from the explicit active certification.
///
/// There is deliberately no exam fallback: onboarding, the local cache, or the
/// profile API must provide a track id so Home can never show the wrong path.
final homeDataProvider = FutureProvider.autoDispose<HomeData>((Ref ref) async {
  final String? trackId = await ref.watch(activeTrackProvider.future);
  if (trackId == null) throw const MissingActiveTrackException();
  final UserProfile profile = await ref.watch(meProvider.future);
  final LearningPath path = await ref.watch(pathProvider(trackId).future);
  return HomeData(profile: profile, path: path);
});

/// The active certification's path, or `null` when none has been selected.
///
/// Having chosen nothing yet is an ordinary first-run *state*, not a failure.
/// [ActivePathScreen] already models it that way — it branches on a null track
/// id as data and offers a way back to the library. [homeDataProvider] instead
/// throws, which is correct for callers that need the aggregate to be
/// all-or-nothing, but it turns Home's whole landing surface into an error the
/// moment a learner has not picked a track.
///
/// This provider carries the same condition as data so Home can degrade one
/// band at a time: the learner's own figures and the Explore shelf do not
/// depend on a certification, and must not disappear with it.
final homePathProvider = FutureProvider.autoDispose<LearningPath?>((Ref ref) async {
  final String? trackId = await ref.watch(activeTrackProvider.future);
  if (trackId == null) {
    return null;
  }
  return ref.watch(pathProvider(trackId).future);
});
