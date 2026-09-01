import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

import 'runtime_content_test_support.dart';

class _BlockingSource implements PublicContentSource {
  _BlockingSource(this.manifest, this.fixture);

  final PublicContentManifest manifest;
  final ContentFixture fixture;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  int manifestCalls = 0;
  int fileCalls = 0;

  @override
  Future<Result<PublicManifestFetch>> fetchActiveManifest({
    String? ifNoneMatch,
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  }) async {
    manifestCalls++;
    if (manifestCalls == 1) {
      started.complete();
      await release.future;
    }

    final String etag = '"${manifest.manifestId}"';
    return Success<PublicManifestFetch>(
      ifNoneMatch == etag
          ? PublicManifestFetch.notModified(
              etag: etag,
              releaseId: manifest.releaseId!,
              publicManifestId: manifest.manifestId,
            )
          : PublicManifestFetch.fetched(manifest, etag),
    );
  }

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String releaseId,
    required String publicManifestId,
    required PublicContentFile file,
    String? ifNoneMatch,
  }) async {
    fileCalls++;
    return Success<PublicContentFileFetch>(
      PublicContentFileFetch.fetched(
        bytes: fixture.bytes,
        etag: '"sha256:${file.hash}"',
        releaseId: releaseId,
        publicManifestId: publicManifestId,
        resourceType: file.resourceType,
      ),
    );
  }
}

class _UnavailableActivationStore extends InMemoryRuntimeContentStore {
  @override
  Future<RuntimeContentActivation?> readActivation(String ownerScope) async {
    throw const FileSystemException('activation unavailable');
  }
}

class _RecordingCleanupStore extends InMemoryRuntimeContentStore {
  final List<Set<String>> protected = <Set<String>>[];

  @override
  Future<void> cleanup({
    required String ownerScope,
    required Set<String> protectedManifestIds,
  }) async {
    protected.add(Set<String>.of(protectedManifestIds));
    await super.cleanup(
      ownerScope: ownerScope,
      protectedManifestIds: protectedManifestIds,
    );
  }
}

class _SecondManifestCallBlockingSource implements PublicContentSource {
  _SecondManifestCallBlockingSource(this.manifest, this.fixture);

  final PublicContentManifest manifest;
  final ContentFixture fixture;
  final Completer<void> secondStarted = Completer<void>();
  final Completer<void> releaseSecond = Completer<void>();
  int manifestCalls = 0;

  @override
  Future<Result<PublicManifestFetch>> fetchActiveManifest({
    String? ifNoneMatch,
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  }) async {
    manifestCalls++;
    if (manifestCalls == 2) {
      secondStarted.complete();
      await releaseSecond.future;
    }
    final String etag = '"${manifest.manifestId}"';
    return Success<PublicManifestFetch>(
      ifNoneMatch == etag
          ? PublicManifestFetch.notModified(
              etag: etag,
              releaseId: manifest.releaseId!,
              publicManifestId: manifest.manifestId,
            )
          : PublicManifestFetch.fetched(manifest, etag),
    );
  }

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String releaseId,
    required String publicManifestId,
    required PublicContentFile file,
    String? ifNoneMatch,
  }) async =>
      Success<PublicContentFileFetch>(
        PublicContentFileFetch.fetched(
          bytes: fixture.bytes,
          etag: '"sha256:${file.hash}"',
          releaseId: releaseId,
          publicManifestId: publicManifestId,
          resourceType: file.resourceType,
        ),
      );
}

void main() {
  const String owner = 'person-1';
  const String pinnedManifest =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('downloads once, activates atomically, then treats 304 as a no-op', () async {
    final ContentFixture first = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[first]);
    final FakePublicContentSource source =
        FakePublicContentSource(release, <ContentFixture>[first]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );

    final RuntimeContentSyncReport initial = await synchronizer.sync(ownerId: owner);
    final RuntimeContentSyncReport unchanged = await synchronizer.sync(ownerId: owner);

    expect(initial.changed, isTrue);
    expect(initial.downloadedFiles, 1);
    expect(unchanged.changed, isFalse);
    expect(source.fileRequests, 1);
    expect(
      (await store.readActivation(runtimeContentScopeKey(owner)))!.activeManifestId,
      release.manifestId,
    );
    await synchronizer.dispose();
  });

  test('304 upgrades a legacy activation with the immutable release binding', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest published = manifest(<ContentFixture>[fixture]);
    final PublicContentManifest legacy = PublicContentManifest.fromJson(published.canonicalJson);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    await store.prepare(legacy);
    await store.writeStagedFile(legacy, legacy.files.single, fixture.bytes);
    await store.activate(
      ownerScope: runtimeContentScopeKey(owner),
      manifest: legacy,
      etag: '"${legacy.manifestId}"',
    );
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: FakePublicContentSource(published, <ContentFixture>[fixture]),
      store: store,
      delay: (_) async {},
    );

    final RuntimeContentSyncReport report = await synchronizer.sync(ownerId: owner);

    expect(report.changed, isFalse);
    expect(report.downloadedFiles, 0);
    expect(report.activation.activeReleaseId, published.releaseId);
    expect(report.activation.activeManifestId, published.manifestId);
    await synchronizer.dispose();
  });

  test('activation storage failure is surfaced through synchronizer status', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: FakePublicContentSource(
        manifest(<ContentFixture>[fixture]),
        <ContentFixture>[fixture],
      ),
      store: _UnavailableActivationStore(),
      delay: (_) async {},
    );

    await expectLater(
      synchronizer.sync(ownerId: owner),
      throwsA(isA<RuntimeContentSyncException>()),
    );

    expect(synchronizer.currentStatus.phase, RuntimeContentPhase.failed);
    expect(synchronizer.currentStatus.message, contains('cache local'));
    await synchronizer.dispose();
  });

  test('reuses unchanged bytes and downloads only a changed file', () async {
    final ContentFixture stable = questionFixture('microsoft.az-900.section-1.cloud.001');
    final ContentFixture old =
        questionFixture('microsoft.az-900.section-1.cloud.002', prompt: 'Ancienne');
    final PublicContentManifest first = manifest(<ContentFixture>[stable, old]);
    final FakePublicContentSource source =
        FakePublicContentSource(first, <ContentFixture>[stable, old]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );
    await synchronizer.sync(ownerId: owner);

    final ContentFixture changed =
        questionFixture('microsoft.az-900.section-1.cloud.002', prompt: 'Nouvelle');
    final PublicContentManifest second = manifest(<ContentFixture>[stable, changed]);
    source.promote(second, <ContentFixture>[stable, changed]);
    final RuntimeContentSyncReport report = await synchronizer.sync(ownerId: owner);

    expect(report.downloadedFiles, 1);
    expect(report.reusedFiles, 1);
    expect(source.fileRequests, 3);
    expect(report.activation.previousManifestId, first.manifestId);
    await synchronizer.dispose();
  });

  test('invalid bytes never replace the last valid activation', () async {
    final ContentFixture first = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest original = manifest(<ContentFixture>[first]);
    final FakePublicContentSource source =
        FakePublicContentSource(original, <ContentFixture>[first]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      limits: const RuntimeContentLimits(maxAttempts: 1),
      delay: (_) async {},
    );
    await synchronizer.sync(ownerId: owner);

    final ContentFixture changed =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'Nouvelle');
    source
      ..promote(manifest(<ContentFixture>[changed]), <ContentFixture>[changed])
      ..corruptNextFile = true;

    await expectLater(
      synchronizer.sync(ownerId: owner),
      throwsA(isA<RuntimeContentSyncException>()),
    );
    expect(
      (await store.readActivation(runtimeContentScopeKey(owner)))!.activeManifestId,
      original.manifestId,
    );
    await synchronizer.dispose();
  });

  test('rollback swaps active and previous releases', () async {
    final ContentFixture first =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N');
    final PublicContentManifest releaseN = manifest(<ContentFixture>[first]);
    final FakePublicContentSource source =
        FakePublicContentSource(releaseN, <ContentFixture>[first]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );
    await synchronizer.sync(ownerId: owner);
    final ContentFixture second =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N+1');
    source.promote(manifest(<ContentFixture>[second]), <ContentFixture>[second]);
    await synchronizer.sync(ownerId: owner);

    final Future<RuntimeContentActivation?> firstRollback = synchronizer.rollback(ownerId: owner);
    final Future<RuntimeContentActivation?> duplicateRollback =
        synchronizer.rollback(ownerId: owner);
    expect(identical(firstRollback, duplicateRollback), isTrue);
    final RuntimeContentActivation? rolledBack = await firstRollback;

    expect(rolledBack!.activeManifestId, releaseN.manifestId);
    expect(rolledBack.activeReleaseId, releaseN.releaseId);
    expect(synchronizer.currentStatus.phase, RuntimeContentPhase.rolledBack);
    await synchronizer.dispose();
  });

  test('rollback waits for every sync already queued before it', () async {
    final ContentFixture first =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N');
    final PublicContentManifest releaseN = manifest(<ContentFixture>[first]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    await store.prepare(releaseN);
    await store.writeStagedFile(releaseN, releaseN.files.single, first.bytes);
    await store.activate(
      ownerScope: runtimeContentScopeKey(owner),
      manifest: releaseN,
      etag: '"${releaseN.manifestId}"',
    );
    final ContentFixture second =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N+1');
    final PublicContentManifest releaseN1 = manifest(<ContentFixture>[second]);
    final _SecondManifestCallBlockingSource source =
        _SecondManifestCallBlockingSource(releaseN1, second);
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );

    final Future<RuntimeContentSyncReport> firstSync = synchronizer.sync(ownerId: owner);
    final Future<RuntimeContentSyncReport> queuedSync = synchronizer.sync(
      ownerId: owner,
      pinnedManifestIds: <String>{pinnedManifest},
    );
    final Future<RuntimeContentActivation?> rollback = synchronizer.rollback(ownerId: owner);
    var rollbackCompleted = false;
    unawaited(
      rollback.then<void>(
        (_) => rollbackCompleted = true,
        onError: (Object _, StackTrace __) => rollbackCompleted = true,
      ),
    );
    await source.secondStarted.future;
    await Future<void>.delayed(Duration.zero);

    expect(rollbackCompleted, isFalse);
    source.releaseSecond.complete();
    await Future.wait<Object?>(<Future<Object?>>[firstSync, queuedSync, rollback]);
    expect(
      (await store.readActivation(runtimeContentScopeKey(owner)))!.activeManifestId,
      releaseN.manifestId,
    );
    await synchronizer.dispose();
  });

  test('sync requested after rollback runs after the rollback barrier', () async {
    final ContentFixture first =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N');
    final PublicContentManifest releaseN = manifest(<ContentFixture>[first]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    await store.prepare(releaseN);
    await store.writeStagedFile(releaseN, releaseN.files.single, first.bytes);
    await store.activate(
      ownerScope: runtimeContentScopeKey(owner),
      manifest: releaseN,
      etag: '"${releaseN.manifestId}"',
    );
    final ContentFixture second =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N+1');
    final PublicContentManifest releaseN1 = manifest(<ContentFixture>[second]);
    final _SecondManifestCallBlockingSource source =
        _SecondManifestCallBlockingSource(releaseN1, second);
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );

    final Future<RuntimeContentSyncReport> firstSync = synchronizer.sync(ownerId: owner);
    final Future<RuntimeContentSyncReport> queuedSync = synchronizer.sync(
      ownerId: owner,
      pinnedManifestIds: <String>{pinnedManifest},
    );
    final Future<RuntimeContentActivation?> rollback = synchronizer.rollback(ownerId: owner);
    final Future<RuntimeContentSyncReport> syncAfterRollback = synchronizer.sync(
      ownerId: owner,
      pinnedManifestIds: <String>{pinnedManifest},
    );
    expect(identical(syncAfterRollback, queuedSync), isFalse);
    await source.secondStarted.future;
    source.releaseSecond.complete();

    await Future.wait<Object?>(
      <Future<Object?>>[firstSync, queuedSync, rollback, syncAfterRollback],
    );
    expect(
      (await store.readActivation(runtimeContentScopeKey(owner)))!.activeManifestId,
      releaseN1.manifestId,
    );
    await synchronizer.dispose();
  });

  test('server rollback reactivates the cached N-1 release without downloading', () async {
    final ContentFixture first = questionFixture(
      'microsoft.az-900.section-1.cloud.001',
      prompt: 'N',
    );
    final PublicContentManifest releaseN = manifest(<ContentFixture>[first]);
    final FakePublicContentSource source = FakePublicContentSource(releaseN, <ContentFixture>[
      first,
    ]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );
    await synchronizer.sync(ownerId: owner);
    final ContentFixture second = questionFixture(
      'microsoft.az-900.section-1.cloud.001',
      prompt: 'N+1',
    );
    final PublicContentManifest releaseN1 = manifest(<ContentFixture>[second]);
    source.promote(releaseN1, <ContentFixture>[second]);
    await synchronizer.sync(ownerId: owner);

    source.promote(releaseN, <ContentFixture>[first]);
    final RuntimeContentSyncReport downgraded = await synchronizer.sync(ownerId: owner);

    expect(downgraded.downloadedFiles, 0);
    expect(downgraded.reusedFiles, 1);
    expect(downgraded.activation.activeReleaseId, releaseN.releaseId);
    expect(downgraded.activation.previousReleaseId, releaseN1.releaseId);
    await synchronizer.dispose();
  });

  test('offline refresh preserves the active release and its readable bytes', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final FakePublicContentSource source = FakePublicContentSource(release, <ContentFixture>[
      fixture,
    ]);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      limits: const RuntimeContentLimits(maxAttempts: 1),
      delay: (_) async {},
    );
    await synchronizer.sync(ownerId: owner);
    source.manifestFailure = const NetworkFailure();

    await expectLater(
      synchronizer.sync(ownerId: owner),
      throwsA(isA<RuntimeContentSyncException>()),
    );

    final RuntimeContentActivation? activation = await store.readActivation(
      runtimeContentScopeKey(owner),
    );
    final CachedPublicContentFile? cached = await store.readActiveFile(
      runtimeContentScopeKey(owner),
      fixture.id,
    );
    expect(activation!.activeManifestId, release.manifestId);
    expect(cached!.bytes, fixture.bytes);
    await synchronizer.dispose();
  });

  test('resumes an interrupted staging transaction without redownloading valid files', () async {
    final Directory root = await Directory.systemTemp.createTemp('certigo-sync-interrupted-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final ContentFixture first = questionFixture('microsoft.az-900.section-1.cloud.001');
    final ContentFixture second = questionFixture('microsoft.az-900.section-1.cloud.002');
    final PublicContentManifest release = manifest(<ContentFixture>[first, second]);
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    await store.prepare(release);
    await store.writeStagedFile(release, release.files.first, first.bytes);
    final FakePublicContentSource source = FakePublicContentSource(release, <ContentFixture>[
      first,
      second,
    ]);
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );

    final RuntimeContentSyncReport report = await synchronizer.sync(ownerId: owner);

    expect(report.downloadedFiles, 1);
    expect(report.reusedFiles, 1);
    expect(source.fileRequests, 1);
    expect(report.activation.activeReleaseId, release.releaseId);
    await synchronizer.dispose();
  });

  test('pin registry is reference counted', () {
    final RuntimeContentPinRegistry pins = RuntimeContentPinRegistry();
    final RuntimeContentPin first = pins.pin(pinnedManifest);
    final RuntimeContentPin second = pins.pin(pinnedManifest);

    first.release();
    first.release();
    expect(pins.manifestIds, hasLength(1));
    second.release();
    expect(pins.manifestIds, isEmpty);
  });

  test('sync action round-trips its pinned public manifest', () {
    final SyncAction action = SyncAction(
      id: '1',
      kind: kQuizSubmitKind,
      endpoint: '/quiz/lesson/submit',
      payload: const <String, dynamic>{},
      idempotencyKey: 'attempt',
      createdAt: DateTime.utc(2026),
      ownerId: owner,
      publicManifestId: pinnedManifest,
    );

    final SyncAction restored = SyncAction.fromJson(action.toJson());

    expect(restored.publicManifestId, action.publicManifestId);
  });

  test('concurrent account syncs are serialized instead of sharing an activation', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final _BlockingSource source = _BlockingSource(release, fixture);
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );

    final Future<RuntimeContentSyncReport> first = synchronizer.sync(ownerId: 'person-a');
    await source.started.future;
    final Future<RuntimeContentSyncReport> second = synchronizer.sync(ownerId: 'person-b');
    source.release.complete();
    await Future.wait<RuntimeContentSyncReport>(<Future<RuntimeContentSyncReport>>[first, second]);

    expect(
      await store.readActivation(runtimeContentScopeKey('person-a')),
      isNotNull,
    );
    expect(
      await store.readActivation(runtimeContentScopeKey('person-b')),
      isNotNull,
    );
    expect(source.manifestCalls, 2);
    expect(source.fileCalls, 1);
    await synchronizer.dispose();
  });

  test('queued sync pins protect cleanup before that sync starts', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final _BlockingSource source = _BlockingSource(release, fixture);
    final _RecordingCleanupStore store = _RecordingCleanupStore();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );

    final Future<RuntimeContentSyncReport> first = synchronizer.sync(ownerId: 'person-a');
    await source.started.future;
    final Future<RuntimeContentSyncReport> queued = synchronizer.sync(
      ownerId: 'person-b',
      pinnedManifestIds: <String>{pinnedManifest},
    );
    source.release.complete();
    await Future.wait<RuntimeContentSyncReport>(<Future<RuntimeContentSyncReport>>[first, queued]);

    expect(store.protected.first, contains(pinnedManifest));
    await synchronizer.dispose();
  });
}
