import 'dart:async';

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
          ? PublicManifestFetch.notModified(etag)
          : PublicManifestFetch.fetched(manifest, etag),
    );
  }

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String publicManifestId,
    required PublicContentFile file,
  }) async {
    fileCalls++;
    return Success<PublicContentFileFetch>(
      PublicContentFileFetch(
        bytes: fixture.bytes,
        etag: '"${file.hash}"',
        publicManifestId: publicManifestId,
        resourceType: file.resourceType,
      ),
    );
  }
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

    final RuntimeContentActivation? rolledBack = await synchronizer.rollback(ownerId: owner);

    expect(rolledBack!.activeManifestId, releaseN.manifestId);
    expect(synchronizer.currentStatus.phase, RuntimeContentPhase.rolledBack);
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
}
