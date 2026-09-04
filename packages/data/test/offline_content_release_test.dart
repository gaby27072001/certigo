import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

const String _manifestA = 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _manifestB = 'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _MemoryStorage {
  final Map<String, String> values = <String, String>{};

  JsonContentReleaseCacheStore store() => JsonContentReleaseCacheStore(
        read: (String key) async => values[key],
        write: (String key, String value) async => values[key] = value,
      );
}

class _FakeContentReleaseRepository implements ContentReleaseRepository {
  _FakeContentReleaseRepository({
    required this.manifestResult,
    this.files = const <String, Result<ContentFileResponse>>{},
  });

  final Result<OfflineContentManifest> manifestResult;
  final Map<String, Result<ContentFileResponse>> files;
  final List<String> requestedPaths = <String>[];

  @override
  Future<Result<OfflineContentManifest>> getActiveManifest() async => manifestResult;

  @override
  Future<Result<ContentFileResponse>> getFile({
    required String manifestId,
    required OfflineContentFileDescriptor descriptor,
  }) async {
    requestedPaths.add(descriptor.path);
    return files[descriptor.path] ??
        const Err<ContentFileResponse>(NotFoundFailure('Missing fake content file.'));
  }
}

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this.result);

  final Result<List<TrackSummary>> result;
  int calls = 0;

  @override
  Future<Result<List<TrackSummary>>> getCatalog() async {
    calls++;
    return result;
  }
}

class _FakeLessonRepository implements LessonRepository {
  _FakeLessonRepository(this.result);

  final Result<Lesson> result;
  int calls = 0;

  @override
  Future<Result<Lesson>> getLesson({required String trackId, required String lessonId}) async {
    calls++;
    return result;
  }
}

void main() {
  group('OfflineContentManifest', () {
    test('rejects private or undeclared manifest fields', () {
      final _ReleaseFixture fixture = _fixture(_manifestA);
      final Map<String, dynamic> json = fixture.manifest.toJson()
        ..['privateManifestId'] = _manifestB;

      expect(() => OfflineContentManifest.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('rejects a non-canonical resource path', () {
      final Map<String, dynamic> json = _fixture(_manifestA).manifest.toJson();
      final List<dynamic> files = json['files']! as List<dynamic>;
      (files.last as Map<String, dynamic>)['path'] = '../private/answer-key.json';

      expect(() => OfflineContentManifest.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('JsonContentReleaseCacheStore', () {
    test('keeps the active generation while a new release is incomplete', () async {
      final _MemoryStorage storage = _MemoryStorage();
      final JsonContentReleaseCacheStore store = storage.store();
      final _ReleaseFixture first = _fixture(_manifestA, catalogTitle: 'First');
      final _ReleaseFixture second = _fixture(
        _manifestB,
        catalogTitle: 'Second',
        lessonBytes: _jsonBytes(_lesson('Second lesson').toJson()),
      );
      await _activate(store, first);

      await store.stageManifest(second.manifest);
      await store.stageFile(
        manifest: second.manifest,
        descriptor: second.manifest.catalog,
        bytes: second.files[second.manifest.catalog.path]!.bytes,
      );

      final ContentReleaseCacheSelection selected = await store.readBest();
      expect(selected.release!.manifest.manifestId, _manifestA);
      expect(
        await store.missingFiles(second.manifest),
        contains(predicate<OfflineContentFileDescriptor>((file) => file.isLesson)),
      );
    });

    test('rejects changed descriptors under an immutable manifest identity', () async {
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      final _ReleaseFixture original = _fixture(_manifestA, catalogTitle: 'Original');
      final _ReleaseFixture changed = _fixture(_manifestA, catalogTitle: 'Changed');
      await store.stageManifest(original.manifest);

      await expectLater(
        store.stageManifest(changed.manifest),
        throwsA(isA<ContentReleaseIntegrityException>()),
      );
    });

    test('falls back to the previous complete generation when active bytes corrupt', () async {
      final _MemoryStorage storage = _MemoryStorage();
      final JsonContentReleaseCacheStore store = storage.store();
      final _ReleaseFixture first = _fixture(_manifestA, catalogTitle: 'First');
      final _ReleaseFixture second = _fixture(_manifestB, catalogTitle: 'Second');
      await _activate(store, first);
      await _activate(store, second);

      final String activeSlot = storage.values[contentReleaseCachePointer]!;
      final Map<String, dynamic> state = Map<String, dynamic>.from(
        jsonDecode(storage.values[activeSlot]!) as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic> generations = Map<String, dynamic>.from(
        state['generations'] as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic> active = Map<String, dynamic>.from(
        generations[_manifestB] as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic> files = Map<String, dynamic>.from(
        active['files'] as Map<dynamic, dynamic>,
      );
      final String catalogPath = second.manifest.catalog.path;
      final Map<String, dynamic> catalog = Map<String, dynamic>.from(
        files[catalogPath] as Map<dynamic, dynamic>,
      );
      catalog['bytes'] = base64Encode(utf8.encode('{"tampered":true}'));
      files[catalogPath] = catalog;
      active['files'] = files;
      generations[_manifestB] = active;
      state['generations'] = generations;
      storage.values[activeSlot] = jsonEncode(state);

      final ContentReleaseCacheSelection selected = await store.readBest();

      expect(selected.release!.manifest.manifestId, _manifestA);
      expect(selected.release!.restoredPrevious, isTrue);
      expect(selected.failure, isA<CacheFailure>());
    });

    test('repairs a corrupt inactive journal slot on a no-op refresh', () async {
      final _MemoryStorage storage = _MemoryStorage();
      final JsonContentReleaseCacheStore store = storage.store();
      final _ReleaseFixture fixture = _fixture(_manifestA);
      await _activate(store, fixture);
      final String activeSlot = storage.values[contentReleaseCachePointer]!;
      final String inactiveSlot = activeSlot == contentReleaseCacheSlotA
          ? contentReleaseCacheSlotB
          : contentReleaseCacheSlotA;
      storage.values[inactiveSlot] = '{broken';

      await store.stageManifest(fixture.manifest);

      final ContentReleaseCacheSelection selected = await store.readBest();
      expect(selected.release!.manifest.manifestId, _manifestA);
      expect(selected.failure, isNull);
      expect(() => jsonDecode(storage.values[inactiveSlot]!), returnsNormally);
    });

    test('rejects private answer fields even when hash and size match', () async {
      final Uint8List privateBytes = _jsonBytes(<String, dynamic>{
        'id': 'lesson-1',
        'answerKey': <String>['a'],
      });
      final _ReleaseFixture fixture = _fixture(_manifestA, lessonBytes: privateBytes);
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      await store.stageManifest(fixture.manifest);

      final Future<void> write = store.stageFile(
        manifest: fixture.manifest,
        descriptor: fixture.lesson,
        bytes: privateBytes,
      );

      await expectLater(write, throwsA(isA<ContentReleaseIntegrityException>()));
    });

    test('rejects bytes that do not match the declared SHA-256', () async {
      final _ReleaseFixture fixture = _fixture(_manifestA);
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      await store.stageManifest(fixture.manifest);

      final Future<void> write = store.stageFile(
        manifest: fixture.manifest,
        descriptor: fixture.lesson,
        bytes: _jsonBytes(_lesson('Tampered').toJson()),
      );

      await expectLater(write, throwsA(isA<ContentReleaseIntegrityException>()));
    });

    test('recovers the committed slot when an interrupted write never flips the pointer', () async {
      final _MemoryStorage storage = _MemoryStorage();
      final JsonContentReleaseCacheStore durable = storage.store();
      final _ReleaseFixture first = _fixture(_manifestA);
      await _activate(durable, first);
      final String committedPointer = storage.values[contentReleaseCachePointer]!;
      final _ReleaseFixture second = _fixture(_manifestB);
      int writes = 0;
      final JsonContentReleaseCacheStore interrupted = JsonContentReleaseCacheStore(
        read: (String key) async => storage.values[key],
        write: (String key, String value) async {
          writes++;
          storage.values[key] = value;
          if (writes == 1) throw StateError('power loss');
        },
      );

      await expectLater(interrupted.stageManifest(second.manifest), throwsA(isA<StateError>()));

      expect(storage.values[contentReleaseCachePointer], committedPointer);
      final ContentReleaseCacheSelection selected = await durable.readBest();
      expect(selected.release!.manifest.manifestId, _manifestA);
    });
  });

  group('ContentReleaseCoordinator', () {
    test('downloads only changed files, then rolls back to N-1 without a download', () async {
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      final _ReleaseFixture first = _fixture(_manifestA, catalogTitle: 'First');
      final _FakeContentReleaseRepository firstRemote = _remote(first);
      final ContentReleaseCoordinator firstCoordinator = ContentReleaseCoordinator(
        remote: firstRemote,
        store: store,
      );
      expect((await firstCoordinator.resolve()).isSuccess, isTrue);
      expect(firstRemote.requestedPaths, hasLength(2));

      final _ReleaseFixture second = _fixture(
        _manifestB,
        catalogTitle: 'Second',
        lessonBytes: first.files[first.lesson.path]!.bytes,
      );
      final _FakeContentReleaseRepository secondRemote = _remote(second);
      final ContentReleaseCoordinator secondCoordinator = ContentReleaseCoordinator(
        remote: secondRemote,
        store: store,
      );
      final ContentReleaseResolution secondResolution =
          (await secondCoordinator.resolve()).valueOrNull!;

      expect(secondResolution.release!.manifest.manifestId, _manifestB);
      expect(secondRemote.requestedPaths, <String>[second.manifest.catalog.path]);

      final _FakeContentReleaseRepository rollbackRemote = _remote(first);
      final ContentReleaseCoordinator rollbackCoordinator = ContentReleaseCoordinator(
        remote: rollbackRemote,
        store: store,
      );
      final ContentReleaseResolution rolledBack =
          (await rollbackCoordinator.resolve()).valueOrNull!;

      expect(rolledBack.release!.manifest.manifestId, _manifestA);
      expect(rollbackRemote.requestedPaths, isEmpty);
    });

    test('resumes an interrupted release and retains the last valid cache offline', () async {
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      final _ReleaseFixture first = _fixture(_manifestA);
      expect(
        (await ContentReleaseCoordinator(remote: _remote(first), store: store).resolve()).isSuccess,
        isTrue,
      );
      final _ReleaseFixture second = _fixture(
        _manifestB,
        catalogTitle: 'New',
        lessonBytes: _jsonBytes(_lesson('New lesson').toJson()),
      );
      final _FakeContentReleaseRepository interrupted = _FakeContentReleaseRepository(
        manifestResult: Success<OfflineContentManifest>(second.manifest),
        files: <String, Result<ContentFileResponse>>{
          second.manifest.catalog.path: Success<ContentFileResponse>(
            second.files[second.manifest.catalog.path]!,
          ),
          second.lesson.path: const Err<ContentFileResponse>(NetworkFailure()),
        },
      );
      final ContentReleaseResolution degraded = (await ContentReleaseCoordinator(
        remote: interrupted,
        store: store,
      ).resolve())
          .valueOrNull!;
      expect(degraded.release!.manifest.manifestId, _manifestA);
      expect(degraded.refreshFailure, isA<NetworkFailure>());

      final _FakeContentReleaseRepository resumed = _remote(second);
      final ContentReleaseResolution completed = (await ContentReleaseCoordinator(
        remote: resumed,
        store: store,
      ).resolve())
          .valueOrNull!;
      expect(completed.release!.manifest.manifestId, _manifestB);
      expect(resumed.requestedPaths, <String>[second.lesson.path]);

      final List<ContentReleaseEvent> events = <ContentReleaseEvent>[];
      final ContentReleaseResolution offline = (await ContentReleaseCoordinator(
        remote: _FakeContentReleaseRepository(
          manifestResult: const Err<OfflineContentManifest>(NetworkFailure()),
        ),
        store: store,
        events: events.add,
      ).resolve())
          .valueOrNull!;
      expect(offline.release!.manifest.manifestId, _manifestB);
      expect(offline.refreshFailure, isA<NetworkFailure>());
      expect(events.single.name, 'content.release.offline.fallback');
    });

    test('does not activate a release when response integrity headers disagree', () async {
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      final _ReleaseFixture first = _fixture(_manifestA);
      await _activate(store, first);
      final _ReleaseFixture second = _fixture(
        _manifestB,
        catalogTitle: 'New',
        lessonBytes: _jsonBytes(_lesson('New').toJson()),
      );
      final Map<String, Result<ContentFileResponse>> files = second.files.map(
        (String path, ContentFileResponse response) =>
            MapEntry<String, Result<ContentFileResponse>>(
          path,
          Success<ContentFileResponse>(
            path == second.manifest.catalog.path
                ? ContentFileResponse(
                    bytes: response.bytes,
                    manifestId: _manifestA,
                    hash: response.hash,
                    size: response.size,
                  )
                : response,
          ),
        ),
      );
      final ContentReleaseResolution resolution = (await ContentReleaseCoordinator(
        remote: _FakeContentReleaseRepository(
          manifestResult: Success<OfflineContentManifest>(second.manifest),
          files: files,
        ),
        store: store,
      ).resolve())
          .valueOrNull!;

      expect(resolution.release!.manifest.manifestId, _manifestA);
      expect(resolution.refreshFailure, isA<CacheFailure>());
    });

    test('migrates a pinned legacy lesson and downloads only the missing catalog', () async {
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      final _ReleaseFixture fixture = _fixture(_manifestA);
      final Map<String, dynamic> legacyLesson = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(fixture.files[fixture.lesson.path]!.bytes)) as Map<dynamic, dynamic>,
      )..['publicManifestId'] = _manifestA;
      final String legacy = jsonEncode(<String, dynamic>{
        'manifestVersion': 'v1',
        'lessons': <String, dynamic>{'az-900/lesson-1': legacyLesson},
      });
      final _FakeContentReleaseRepository remote = _remote(fixture);
      final ContentReleaseResolution resolution = (await ContentReleaseCoordinator(
        remote: remote,
        store: store,
        readLegacyLessons: () async => legacy,
      ).resolve())
          .valueOrNull!;

      expect(resolution.release!.manifest.manifestId, _manifestA);
      expect(remote.requestedPaths, <String>[fixture.manifest.catalog.path]);
    });

    test('uses legacy repositories only when the manifest capability is unavailable', () async {
      final ContentReleaseCoordinator coordinator = ContentReleaseCoordinator(
        remote: _FakeContentReleaseRepository(
          manifestResult: const Err<OfflineContentManifest>(NotFoundFailure()),
        ),
        store: _MemoryStorage().store(),
      );
      final _FakeCatalogRepository catalogLegacy = _FakeCatalogRepository(
        Success<List<TrackSummary>>(<TrackSummary>[_track('Legacy')]),
      );
      final _FakeLessonRepository lessonLegacy = _FakeLessonRepository(
        Success<Lesson>(_lesson('Legacy')),
      );

      final Result<List<TrackSummary>> catalog = await ReleaseAwareCatalogRepository(
        coordinator: coordinator,
        legacy: catalogLegacy,
      ).getCatalog();
      final Result<Lesson> lesson = await ReleaseAwareLessonRepository(
        coordinator: coordinator,
        legacy: lessonLegacy,
      ).getLesson(trackId: 'az-900', lessonId: 'lesson-1');

      expect(catalog.valueOrNull!.single.title, 'Legacy');
      expect(lesson.valueOrNull!.title, 'Legacy');
      expect(catalogLegacy.calls, 1);
      expect(lessonLegacy.calls, 1);
    });

    test('keeps a supported cached release when a future manifest cannot be parsed', () async {
      final JsonContentReleaseCacheStore store = _MemoryStorage().store();
      final _ReleaseFixture fixture = _fixture(_manifestA);
      await _activate(store, fixture);
      final List<ContentReleaseEvent> events = <ContentReleaseEvent>[];
      final ContentReleaseResolution resolution = (await ContentReleaseCoordinator(
        remote: _FakeContentReleaseRepository(
          manifestResult: const Err<OfflineContentManifest>(ParseFailure()),
        ),
        store: store,
        events: events.add,
      ).resolve())
          .valueOrNull!;

      expect(resolution.release!.manifest.schema, offlineContentManifestV1);
      expect(resolution.refreshFailure, isA<ParseFailure>());
      expect(events.single.failureCode, 'parse');
    });

    test('does not hide corruption when neither active nor previous cache is valid', () async {
      final _MemoryStorage storage = _MemoryStorage();
      storage.values[contentReleaseCacheSlotA] = '{broken';
      storage.values[contentReleaseCacheSlotB] = '{also-broken';
      storage.values[contentReleaseCachePointer] = contentReleaseCacheSlotA;
      final Result<ContentReleaseResolution> result = await ContentReleaseCoordinator(
        remote: _FakeContentReleaseRepository(
          manifestResult: const Err<OfflineContentManifest>(NetworkFailure()),
        ),
        store: storage.store(),
      ).resolve();

      expect(result.isFailure, isTrue);
      expect((result as Err<ContentReleaseResolution>).failure, isA<CacheFailure>());
    });

    test('reports cache corruption and the concurrent network failure independently', () async {
      final _MemoryStorage storage = _MemoryStorage();
      final JsonContentReleaseCacheStore store = storage.store();
      final _ReleaseFixture first = _fixture(_manifestA);
      final _ReleaseFixture second = _fixture(_manifestB);
      await _activate(store, first);
      await _activate(store, second);
      final String activeSlot = storage.values[contentReleaseCachePointer]!;
      final Map<String, dynamic> state = Map<String, dynamic>.from(
        jsonDecode(storage.values[activeSlot]!) as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic> generations = Map<String, dynamic>.from(
        state['generations'] as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic> active = Map<String, dynamic>.from(
        generations[_manifestB] as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic> files = Map<String, dynamic>.from(
        active['files'] as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic> catalog = Map<String, dynamic>.from(
        files[second.manifest.catalog.path] as Map<dynamic, dynamic>,
      )..['bytes'] = base64Encode(utf8.encode('{"tampered":true}'));
      files[second.manifest.catalog.path] = catalog;
      active['files'] = files;
      generations[_manifestB] = active;
      state['generations'] = generations;
      storage.values[activeSlot] = jsonEncode(state);
      final List<ContentReleaseEvent> events = <ContentReleaseEvent>[];

      final ContentReleaseResolution resolution = (await ContentReleaseCoordinator(
        remote: _FakeContentReleaseRepository(
          manifestResult: const Err<OfflineContentManifest>(NetworkFailure()),
        ),
        store: store,
        events: events.add,
      ).resolve())
          .valueOrNull!;

      expect(resolution.release!.manifest.manifestId, _manifestA);
      expect(resolution.release!.restoredPrevious, isTrue);
      expect(resolution.refreshFailure, isA<NetworkFailure>());
      expect(
        events.map((ContentReleaseEvent event) => (event.name, event.failureCode)),
        <(String, String?)>[
          ('content.release.offline.cache_corrupt', 'cache'),
          ('content.release.offline.fallback', 'network'),
        ],
      );
    });

    test('reports and repairs a corrupt journal when the release is reachable', () async {
      final _MemoryStorage storage = _MemoryStorage();
      storage.values[contentReleaseCacheSlotA] = '{broken';
      storage.values[contentReleaseCacheSlotB] = '{also-broken';
      storage.values[contentReleaseCachePointer] = contentReleaseCacheSlotA;
      final _ReleaseFixture fixture = _fixture(_manifestA);
      final List<ContentReleaseEvent> events = <ContentReleaseEvent>[];

      final ContentReleaseResolution resolution = (await ContentReleaseCoordinator(
        remote: _remote(fixture),
        store: storage.store(),
        events: events.add,
      ).resolve())
          .valueOrNull!;
      final ContentReleaseCacheSelection selected = await storage.store().readBest();

      expect(resolution.release!.manifest.manifestId, _manifestA);
      expect(selected.release!.manifest.manifestId, _manifestA);
      expect(selected.failure, isNull);
      expect(events.first.name, 'content.release.offline.cache_corrupt');
      expect(events.first.failureCode, 'cache');
    });
  });
}

class _ReleaseFixture {
  const _ReleaseFixture({required this.manifest, required this.lesson, required this.files});

  final OfflineContentManifest manifest;
  final OfflineContentFileDescriptor lesson;
  final Map<String, ContentFileResponse> files;
}

_ReleaseFixture _fixture(
  String manifestId, {
  String catalogTitle = 'Azure Fundamentals',
  Uint8List? lessonBytes,
}) {
  final Uint8List catalog = _jsonBytes(<String, dynamic>{
    'schema': 'certigo.app-certification-catalog/v2',
    'sourceSchema': 'certigo.certification-catalog/v1',
    'tracks': <Map<String, dynamic>>[_track(catalogTitle).toJson()],
  });
  final Uint8List lesson = lessonBytes ?? _jsonBytes(_lesson('Lesson').toJson());
  final OfflineContentFileDescriptor catalogDescriptor = _descriptor(
    id: 'catalog',
    path: 'catalog/tracks.json',
    resourceType: catalogContentResourceType,
    bytes: catalog,
  );
  final OfflineContentFileDescriptor lessonDescriptor = _descriptor(
    id: 'lesson-1',
    path: 'tracks/az-900/lessons/lesson-1.json',
    resourceType: lessonContentResourceType,
    trackId: 'az-900',
    bytes: lesson,
  );
  final OfflineContentManifest manifest = OfflineContentManifest(
    schema: offlineContentManifestV1,
    manifestId: manifestId,
    sourceSchema: packageManifestV3,
    files: <OfflineContentFileDescriptor>[catalogDescriptor, lessonDescriptor],
  );
  return _ReleaseFixture(
    manifest: manifest,
    lesson: lessonDescriptor,
    files: <String, ContentFileResponse>{
      catalogDescriptor.path: _response(manifestId, catalogDescriptor, catalog),
      lessonDescriptor.path: _response(manifestId, lessonDescriptor, lesson),
    },
  );
}

_FakeContentReleaseRepository _remote(_ReleaseFixture fixture) => _FakeContentReleaseRepository(
      manifestResult: Success<OfflineContentManifest>(fixture.manifest),
      files: fixture.files.map(
        (String path, ContentFileResponse response) =>
            MapEntry<String, Result<ContentFileResponse>>(
                path, Success<ContentFileResponse>(response)),
      ),
    );

Future<void> _activate(ContentReleaseCacheStore store, _ReleaseFixture fixture) async {
  await store.stageManifest(fixture.manifest);
  for (final OfflineContentFileDescriptor descriptor in fixture.manifest.files) {
    await store.stageFile(
      manifest: fixture.manifest,
      descriptor: descriptor,
      bytes: fixture.files[descriptor.path]!.bytes,
    );
  }
  await store.activate(fixture.manifest);
}

OfflineContentFileDescriptor _descriptor({
  required String id,
  required String path,
  required String resourceType,
  required Uint8List bytes,
  String? trackId,
}) =>
    OfflineContentFileDescriptor(
      id: id,
      path: path,
      resourceType: resourceType,
      hash: sha256.convert(bytes).toString(),
      size: bytes.length,
      trackId: trackId,
    );

ContentFileResponse _response(
  String manifestId,
  OfflineContentFileDescriptor descriptor,
  Uint8List bytes,
) =>
    ContentFileResponse(
      bytes: bytes,
      manifestId: manifestId,
      hash: descriptor.hash,
      size: descriptor.size,
    );

Uint8List _jsonBytes(Map<String, dynamic> value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

TrackSummary _track(String title) => TrackSummary(
      id: 'az-900',
      code: 'AZ-900',
      title: title,
      level: 'fundamentals',
      summary: 'Summary',
      unitCount: 1,
      lessonCount: 1,
    );

Lesson _lesson(String title) => Lesson(
      id: 'lesson-1',
      trackId: 'az-900',
      unitId: 'unit-1',
      domainId: 'domain-1',
      title: title,
      estMinutes: 5,
      blocks: const <LessonBlock>[],
    );
