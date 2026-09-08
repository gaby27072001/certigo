import 'dart:convert';
import 'dart:io';

import 'package:data/data.dart';
import 'package:test/test.dart';

import 'runtime_content_test_support.dart';

class _FailingPurgeStore extends InMemoryRuntimeContentStore {
  @override
  Future<void> purgePerson(String ownerScope) async {
    throw const FileSystemException('person purge failed');
  }
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('certigo-runtime-content-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('uses generation files for atomic activation and recovers N-1', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String owner = runtimeContentScopeKey('person-1');
    final ContentFixture first =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N');
    final PublicContentManifest releaseN = manifest(<ContentFixture>[first]);
    await store.prepare(releaseN);
    await store.writeStagedFile(releaseN, releaseN.files.single, first.bytes);
    await store.activate(ownerScope: owner, manifest: releaseN, etag: '"${releaseN.manifestId}"');

    final ContentFixture second =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N+1');
    final PublicContentManifest releaseN1 = manifest(<ContentFixture>[second]);
    await store.prepare(releaseN1);
    await store.writeStagedFile(releaseN1, releaseN1.files.single, second.bytes);
    await store.activate(
      ownerScope: owner,
      manifest: releaseN1,
      etag: '"${releaseN1.manifestId}"',
    );

    final RuntimeContentActivation? rolledBack = await store.rollback(owner);
    final CachedPublicContentFile? cached = await store.readActiveFile(owner, first.id);

    expect(rolledBack!.activeManifestId, releaseN.manifestId);
    expect(rolledBack.activeReleaseId, releaseN.releaseId);
    expect(cached!.publicManifestId, releaseN.manifestId);
    expect(cached.releaseId, releaseN.releaseId);
    expect(cached.bytes, first.bytes);
  });

  test('ignores an incomplete newest generation after a simulated crash', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String owner = runtimeContentScopeKey('person-1');
    final ContentFixture first =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N');
    final PublicContentManifest releaseN = manifest(<ContentFixture>[first]);
    await store.prepare(releaseN);
    await store.writeStagedFile(releaseN, releaseN.files.single, first.bytes);
    await store.activate(ownerScope: owner, manifest: releaseN, etag: '"${releaseN.manifestId}"');

    final ContentFixture second =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'N+1');
    final PublicContentManifest releaseN1 = manifest(<ContentFixture>[second]);
    await store.prepare(releaseN1);
    await store.writeStagedFile(releaseN1, releaseN1.files.single, second.bytes);
    await store.activate(
      ownerScope: owner,
      manifest: releaseN1,
      etag: '"${releaseN1.manifestId}"',
    );
    final File marker = File(
      '${root.path}${Platform.pathSeparator}public${Platform.pathSeparator}spaces'
      '${Platform.pathSeparator}test-space${Platform.pathSeparator}releases'
      '${Platform.pathSeparator}${releaseN1.manifestId.substring(7)}'
      '${Platform.pathSeparator}complete',
    );
    await marker.delete();

    final RuntimeContentActivation? recovered = await store.readActivation(owner);

    expect(recovered!.activeManifestId, releaseN.manifestId);
    expect(recovered.recovered, isTrue);
  });

  test('cleanup preserves active releases for every account in the space', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String ownerA = runtimeContentScopeKey('person-a');
    final String ownerB = runtimeContentScopeKey('person-b');
    final ContentFixture first =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'A');
    final PublicContentManifest releaseA = manifest(<ContentFixture>[first]);
    await store.prepare(releaseA);
    await store.writeStagedFile(releaseA, releaseA.files.single, first.bytes);
    await store.activate(ownerScope: ownerA, manifest: releaseA, etag: '"${releaseA.manifestId}"');

    final ContentFixture second =
        questionFixture('microsoft.az-900.section-1.cloud.001', prompt: 'B');
    final PublicContentManifest releaseB = manifest(<ContentFixture>[second]);
    await store.prepare(releaseB);
    await store.writeStagedFile(releaseB, releaseB.files.single, second.bytes);
    await store.activate(ownerScope: ownerB, manifest: releaseB, etag: '"${releaseB.manifestId}"');

    await store.cleanup(ownerScope: ownerB, protectedManifestIds: const <String>{});

    expect(await store.readActiveFile(ownerA, first.id), isNotNull);
    expect(await store.readActiveFile(ownerB, second.id), isNotNull);
  });

  test('keeps the persisted cache readable by the previous mobile schema', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String owner = runtimeContentScopeKey('person-1');
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    await store.prepare(release);
    await store.writeStagedFile(release, release.files.single, fixture.bytes);
    await store.activate(ownerScope: owner, manifest: release, etag: '"${release.manifestId}"');
    final String cacheRoot = '${root.path}${Platform.pathSeparator}public'
        '${Platform.pathSeparator}spaces${Platform.pathSeparator}test-space';
    final File persistedManifest = File(
      '$cacheRoot${Platform.pathSeparator}releases${Platform.pathSeparator}'
      '${release.manifestId.substring(7)}${Platform.pathSeparator}manifest.json',
    );
    final Directory activations = Directory(
      '${root.path}${Platform.pathSeparator}person${Platform.pathSeparator}$owner'
      '${Platform.pathSeparator}spaces${Platform.pathSeparator}test-space'
      '${Platform.pathSeparator}activations',
    );
    final File activationFile = (await activations
            .list()
            .where((FileSystemEntity entity) => entity is File)
            .cast<File>()
            .toList())
        .single;
    final Map<String, dynamic> manifestJson = Map<String, dynamic>.from(
      jsonDecode(await persistedManifest.readAsString()) as Map,
    );
    final Map<String, dynamic> activationJson = Map<String, dynamic>.from(
      jsonDecode(await activationFile.readAsString()) as Map,
    );

    expect(manifestJson, isNot(contains('releaseId')));
    expect(activationJson['schema'], 'certigo.mobile.content-activation/v1');
    expect(activationJson['activeReleaseId'], release.releaseId);
    expect(PublicContentManifest.fromJson(manifestJson).manifestId, release.manifestId);
  });

  test('same-size corruption invalidates the newest activation', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String owner = runtimeContentScopeKey('person-1');
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    await store.prepare(release);
    await store.writeStagedFile(release, release.files.single, fixture.bytes);
    await store.activate(ownerScope: owner, manifest: release, etag: '"${release.manifestId}"');
    final File cached = File(
      '${root.path}${Platform.pathSeparator}public${Platform.pathSeparator}spaces'
      '${Platform.pathSeparator}test-space${Platform.pathSeparator}releases'
      '${Platform.pathSeparator}${release.manifestId.substring(7)}'
      '${Platform.pathSeparator}files${Platform.pathSeparator}${release.files.single.hash}.json',
    );
    final List<int> tampered = await cached.readAsBytes();
    tampered[1] ^= 0x01;
    await cached.writeAsBytes(tampered, flush: true);

    expect(await store.readActivation(owner), isNull);
  });

  test('person purge preserves another person and shared release bytes', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String ownerA = runtimeContentScopeKey('person-a');
    final String ownerB = runtimeContentScopeKey('person-b');
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    await store.prepare(release);
    await store.writeStagedFile(release, release.files.single, fixture.bytes);
    await store.activate(ownerScope: ownerA, manifest: release, etag: '"${release.manifestId}"');
    await store.activate(ownerScope: ownerB, manifest: release, etag: '"${release.manifestId}"');

    await store.purgePerson(ownerA);

    expect(await store.readActivation(ownerA), isNull);
    expect(await store.readActivation(ownerB), isNotNull);
    expect((await store.readActiveFile(ownerB, fixture.id))!.bytes, fixture.bytes);
  });

  test('person purge resumes an interrupted atomic tombstone deletion', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String owner = runtimeContentScopeKey('person-1');
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    await store.prepare(release);
    await store.writeStagedFile(release, release.files.single, fixture.bytes);
    await store.activate(ownerScope: owner, manifest: release, etag: '"${release.manifestId}"');
    final Directory personRoot = Directory(
      '${root.path}${Platform.pathSeparator}person${Platform.pathSeparator}$owner',
    );
    final Directory tombstone = Directory('${personRoot.path}.deleting');
    await personRoot.rename(tombstone.path);
    final FileRuntimeContentStore restarted = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    await expectLater(
      restarted.activate(
        ownerScope: owner,
        manifest: release,
        etag: '"${release.manifestId}"',
      ),
      throwsStateError,
    );

    await restarted.purgePerson(owner);

    expect(await personRoot.exists(), isFalse);
    expect(await tombstone.exists(), isFalse);
  });

  test('person purge serializes activation and fences later recreation', () async {
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    final String owner = runtimeContentScopeKey('person-1');
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    await store.prepare(release);
    await store.writeStagedFile(release, release.files.single, fixture.bytes);

    final Future<RuntimeContentActivation> activating = store.activate(
      ownerScope: owner,
      manifest: release,
      etag: '"${release.manifestId}"',
    );
    final Future<void> purging = store.purgePerson(owner);
    await activating;
    await purging;

    expect(await store.readActivation(owner), isNull);
    await expectLater(
      store.activate(
        ownerScope: owner,
        manifest: release,
        etag: '"${release.manifestId}"',
      ),
      throwsStateError,
    );
    final FileRuntimeContentStore restarted = FileRuntimeContentStore(
      root: root,
      spaceScope: 'test-space',
    );
    await expectLater(
      restarted.activate(
        ownerScope: owner,
        manifest: release,
        etag: '"${release.manifestId}"',
      ),
      throwsStateError,
    );
  });

  test('confirmed person purge releases only that owner leases', () async {
    final InMemoryRuntimeContentStore store = InMemoryRuntimeContentStore();
    final RuntimeContentPinRegistry pins = RuntimeContentPinRegistry();
    final RuntimeContentPersonPurger purger = RuntimeContentPersonPurger(
      store: store,
      pins: pins,
    );
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    await store.prepare(release);
    await store.writeStagedFile(release, release.files.single, fixture.bytes);
    await store.activate(
      ownerScope: runtimeContentScopeKey('person-a'),
      manifest: release,
      etag: '"${release.manifestId}"',
    );
    await store.activate(
      ownerScope: runtimeContentScopeKey('person-b'),
      manifest: release,
      etag: '"${release.manifestId}"',
    );
    pins.pin(release.manifestId, ownerId: 'person-a');
    final RuntimeContentPin personBPin = pins.pin(release.manifestId, ownerId: 'person-b');

    await purger.purge(personId: 'person-a', serverConfirmed: true);

    expect(await store.readActivation(runtimeContentScopeKey('person-a')), isNull);
    expect(await store.readActivation(runtimeContentScopeKey('person-b')), isNotNull);
    expect(pins.manifestIds, <String>{release.manifestId});
    personBPin.release();
    expect(pins.manifestIds, isEmpty);
  });

  test('person purge refuses pre-confirmation and retains leases when storage fails', () async {
    final RuntimeContentPinRegistry pins = RuntimeContentPinRegistry();
    final RuntimeContentPin pin = pins.pin(
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ownerId: 'person-a',
    );
    final RuntimeContentPersonPurger purger = RuntimeContentPersonPurger(
      store: _FailingPurgeStore(),
      pins: pins,
    );

    await expectLater(
      purger.purge(personId: 'person-a', serverConfirmed: false),
      throwsStateError,
    );
    await expectLater(
      purger.purge(personId: 'person-a', serverConfirmed: true),
      throwsA(isA<FileSystemException>()),
    );

    expect(pins.manifestIds, isNotEmpty);
    pin.release();
  });
}
