import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

/// Hermetic offline-study-cache tests (wp-p1-08).
///
/// These are deliberately network-free and platform-free: the "remote" is a
/// scripted fake and the durable store is a [JsonLessonCacheStore] backed by an
/// in-memory string. No SharedPreferences, no HTTP, no google_fonts — so they
/// run fast under a targeted `dart test` without touching the (red) app build.

/// A [LessonRepository] fake that returns queued results in order, repeating the
/// last one once the queue is exhausted. Lets one test model "first the download
/// succeeds, then the network is gone" for airplane-mode reads.
class _ScriptedLessonRepository implements LessonRepository {
  _ScriptedLessonRepository(this._results);

  final List<Result<Lesson>> _results;
  int _calls = 0;

  int get calls => _calls;

  @override
  Future<Result<Lesson>> getLesson({required String trackId, required String lessonId}) async {
    final int index = _calls < _results.length ? _calls : _results.length - 1;
    _calls++;
    return _results[index];
  }
}

/// A mutable string cell so a [JsonLessonCacheStore] can persist across calls
/// without any platform channel — this is the hermetic stand-in for disk.
class _StringCell {
  String? value;
}

Lesson _lesson({
  String id = 'intro',
  String trackId = 'az-900',
  String title = 'Cloud concepts',
}) =>
    Lesson(
      id: id,
      trackId: trackId,
      unitId: 'unit-1',
      domainId: 'domain-1',
      title: title,
      estMinutes: 7,
      blocks: <LessonBlock>[
        const LessonBlock(
          type: BlockType.concept,
          conceptId: 'c1',
          title: 'What is the cloud',
          body: 'On-demand compute over the network.',
        ),
      ],
    );

JsonLessonCacheStore _jsonStore(_StringCell cell) => JsonLessonCacheStore(
      read: () async => cell.value,
      write: (String json) async => cell.value = json,
    );

void main() {
  group('OfflineLessonRepository (offline study cache)', () {
    test('downloads on success then serves the lesson offline (airplane mode)', () async {
      // First call succeeds (the "download"); second call has no network.
      final _ScriptedLessonRepository inner = _ScriptedLessonRepository(<Result<Lesson>>[
        Success<Lesson>(_lesson(title: 'Cloud concepts')),
        const Err<Lesson>(NetworkFailure()),
      ]);
      final _StringCell cell = _StringCell();
      final OfflineLessonRepository repo = OfflineLessonRepository(
        inner,
        _jsonStore(cell),
        'v1',
      );

      // Download for offline.
      final Result<Lesson> downloaded = await repo.prefetch(trackId: 'az-900', lessonId: 'intro');
      expect(downloaded.isSuccess, isTrue);
      expect(cell.value, isNotNull, reason: 'prefetch should persist the lesson to the cache');

      // Now read with the network gone — must come from the cache.
      final Result<Lesson> offline = await repo.getLesson(trackId: 'az-900', lessonId: 'intro');
      expect(offline.isSuccess, isTrue);
      final Lesson lesson = (offline as Success<Lesson>).value;
      expect(lesson.id, 'intro');
      expect(lesson.title, 'Cloud concepts');
      expect(lesson.blocks.single.body, 'On-demand compute over the network.');
      expect(inner.calls, 2, reason: 'the offline read still hits the (failing) remote first');
    });

    test('invalidates the cache when the manifest version changes', () async {
      final _StringCell cell = _StringCell();
      final JsonLessonCacheStore store = _jsonStore(cell);

      // Cache a lesson under v1 via a v1-scoped decorator.
      final OfflineLessonRepository v1 = OfflineLessonRepository(
        _ScriptedLessonRepository(<Result<Lesson>>[Success<Lesson>(_lesson(id: 'a'))]),
        store,
        'v1',
      );
      await v1.prefetch(trackId: 'az-900', lessonId: 'a');

      // A different lesson under v2 must purge every v1 entry (single-key policy).
      final OfflineLessonRepository v2 = OfflineLessonRepository(
        _ScriptedLessonRepository(<Result<Lesson>>[Success<Lesson>(_lesson(id: 'b'))]),
        store,
        'v2',
      );
      await v2.prefetch(trackId: 'az-900', lessonId: 'b');

      // v1 content is gone under both the old and the new version.
      expect(await store.read(manifestVersion: 'v1', trackId: 'az-900', lessonId: 'a'), isNull);
      expect(await store.read(manifestVersion: 'v2', trackId: 'az-900', lessonId: 'a'), isNull);
      // The v2 lesson is present under v2.
      final Lesson? b = await store.read(manifestVersion: 'v2', trackId: 'az-900', lessonId: 'b');
      expect(b, isNotNull);
      expect(b!.id, 'b');
    });

    test('a lesson cached under an older manifest version is a miss', () async {
      final _StringCell cell = _StringCell();
      final JsonLessonCacheStore store = _jsonStore(cell);
      await store.write(manifestVersion: 'v1', lesson: _lesson(id: 'a'));

      // Same lesson, newer manifest => invalidated.
      expect(await store.read(manifestVersion: 'v2', trackId: 'az-900', lessonId: 'a'), isNull);
      // Same manifest => still readable.
      expect(await store.read(manifestVersion: 'v1', trackId: 'az-900', lessonId: 'a'), isNotNull);
    });

    test('serves cache on a transient failure', () async {
      final _StringCell cell = _StringCell();
      final JsonLessonCacheStore store = _jsonStore(cell);
      await store.write(manifestVersion: 'v1', lesson: _lesson(id: 'intro', title: 'Cached'));

      final OfflineLessonRepository repo = OfflineLessonRepository(
        _ScriptedLessonRepository(<Result<Lesson>>[const Err<Lesson>(NetworkFailure())]),
        store,
        'v1',
      );

      final Result<Lesson> result = await repo.getLesson(trackId: 'az-900', lessonId: 'intro');
      expect(result.isSuccess, isTrue);
      expect((result as Success<Lesson>).value.title, 'Cached');
    });

    test('propagates a permanent failure even when a cache entry exists', () async {
      final _StringCell cell = _StringCell();
      final JsonLessonCacheStore store = _jsonStore(cell);
      await store.write(manifestVersion: 'v1', lesson: _lesson(id: 'intro'));

      final OfflineLessonRepository repo = OfflineLessonRepository(
        _ScriptedLessonRepository(<Result<Lesson>>[const Err<Lesson>(NotFoundFailure())]),
        store,
        'v1',
      );

      final Result<Lesson> result = await repo.getLesson(trackId: 'az-900', lessonId: 'intro');
      expect(result.isFailure, isTrue);
      expect((result as Err<Lesson>).failure, isA<NotFoundFailure>());
    });

    test('returns the original transient failure when the cache is empty', () async {
      final OfflineLessonRepository repo = OfflineLessonRepository(
        _ScriptedLessonRepository(<Result<Lesson>>[const Err<Lesson>(NetworkFailure())]),
        _jsonStore(_StringCell()),
        'v1',
      );

      final Result<Lesson> result = await repo.getLesson(trackId: 'az-900', lessonId: 'intro');
      expect(result.isFailure, isTrue);
      expect((result as Err<Lesson>).failure, isA<NetworkFailure>());
    });
  });
}
