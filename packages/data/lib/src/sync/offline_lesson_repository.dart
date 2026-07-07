import 'package:core/core.dart';

import '../models/lesson.dart';
import '../repositories/repositories.dart';
import 'lesson_cache_store.dart';
import 'sync_dispatcher.dart';

/// A [LessonRepository] decorator that makes a study session downloadable and
/// readable offline.
///
/// On remote success it writes the lesson through to the version-aware cache
/// (this is the "download"): the content is then readable in airplane mode. On
/// transient failures (network, auth refresh windows, 5xx/429) it serves the
/// last cached lesson for the current manifest version when available. Permanent
/// failures are propagated unchanged. Cache invalidation is handled by the store:
/// a lesson cached under a previous manifest version is a miss and is purged on
/// the next write.
class OfflineLessonRepository implements LessonRepository {
  OfflineLessonRepository(this._inner, this._cacheStore, this._manifestVersion);

  final LessonRepository _inner;
  final LessonCacheStore _cacheStore;
  final String _manifestVersion;

  @override
  Future<Result<Lesson>> getLesson({required String trackId, required String lessonId}) async {
    final Result<Lesson> result = await _inner.getLesson(trackId: trackId, lessonId: lessonId);

    if (result case Success<Lesson>(:final Lesson value)) {
      await _cacheStore.write(manifestVersion: _manifestVersion, lesson: value);
      return result;
    }

    final Failure failure = (result as Err<Lesson>).failure;
    if (classifyFailure(failure) == SyncDispatch.retryable) {
      final Lesson? cached = await _cacheStore.read(
        manifestVersion: _manifestVersion,
        trackId: trackId,
        lessonId: lessonId,
      );
      if (cached != null) return Success<Lesson>(cached);
    }

    return result;
  }

  /// Explicitly downloads a study session and persists it for offline reading.
  ///
  /// Semantically identical to [getLesson] (which already caches on success),
  /// exposed under an intent-revealing name for the "download for offline" UX.
  Future<Result<Lesson>> prefetch({required String trackId, required String lessonId}) =>
      getLesson(trackId: trackId, lessonId: lessonId);
}
