import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

import 'runtime_content_test_support.dart';

class _RecordingTelemetry implements RuntimeContentTelemetry {
  final List<RuntimeContentSyncEvent> syncs = <RuntimeContentSyncEvent>[];
  final List<RuntimeContentRollbackEvent> rollbacks = <RuntimeContentRollbackEvent>[];

  @override
  void syncFinished(RuntimeContentSyncEvent event) => syncs.add(event);

  @override
  void rollbackFinished(RuntimeContentRollbackEvent event) => rollbacks.add(event);
}

/// Answer material that must never reach the device. `releaseId` is excluded on
/// purpose: it is a public identity the cache records in its own metadata.
const Set<String> _answerMaterialKeys = <String>{
  'answerkey',
  'correct',
  'correctoptionids',
  'explanation',
  'privatemanifestid',
  'rationale',
  'solution',
};

Set<String> _answerKeysIn(dynamic value) {
  if (value is Map) {
    return <String>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries) ...<String>{
        if (_answerMaterialKeys.contains('${entry.key}'.toLowerCase())) '${entry.key}',
        ..._answerKeysIn(entry.value),
      },
    };
  }
  if (value is List) {
    return <String>{for (final dynamic item in value) ..._answerKeysIn(item)};
  }
  return const <String>{};
}

/// Every answer-material key found in any JSON document written under [root],
/// and every file that is not JSON (the cache must only hold JSON documents).
Future<Map<String, Set<String>>> _scanDeviceCache(Directory root) async {
  final Map<String, Set<String>> findings = <String, Set<String>>{};
  await for (final FileSystemEntity entity in root.list(recursive: true)) {
    if (entity is! File) continue;
    final String text = await entity.readAsString();
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      final Set<String> leaked =
          _answerMaterialKeys.where((String key) => text.toLowerCase().contains('"$key"')).toSet();
      if (leaked.isNotEmpty) findings[entity.path] = leaked;
      continue;
    }
    final Set<String> leaked = _answerKeysIn(decoded);
    if (leaked.isNotEmpty) findings[entity.path] = leaked;
  }
  return findings;
}

void main() {
  const String owner = 'person-1';
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('certigo-offline-resilience-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  FileRuntimeContentStore diskStore() =>
      FileRuntimeContentStore(root: root, spaceScope: 'resilience-space');

  test('a connection lost mid-download keeps N-1 usable offline, then resumes to N', () async {
    final ContentFixture stable = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest releaseN1 = manifest(<ContentFixture>[stable]);
    final FakePublicContentSource source =
        FakePublicContentSource(releaseN1, <ContentFixture>[stable]);
    final _RecordingTelemetry telemetry = _RecordingTelemetry();
    final RuntimeContentSynchronizer online = RuntimeContentSynchronizer(
      source: source,
      store: diskStore(),
      limits: const RuntimeContentLimits(maxAttempts: 1),
      delay: (_) async {},
      telemetry: telemetry,
    );
    await online.sync(ownerId: owner);

    final List<ContentFixture> releaseNFiles = <ContentFixture>[
      stable,
      questionFixture('microsoft.az-900.section-1.cloud.002', prompt: 'Nouvelle question ?'),
      questionFixture('microsoft.az-900.section-1.cloud.003', prompt: 'Autre question ?'),
    ];
    final PublicContentManifest releaseN = manifest(releaseNFiles);
    source
      ..promote(releaseN, releaseNFiles)
      ..servedFiles = 0
      ..failFilesAfter = 1;

    await expectLater(
      online.sync(ownerId: owner),
      throwsA(isA<RuntimeContentSyncException>()),
    );
    await online.dispose();

    final RuntimeContentSyncEvent interrupted = telemetry.syncs.last;
    expect(interrupted.outcome, RuntimeContentSyncOutcome.failed);
    expect(interrupted.failureStage, RuntimeContentFailureStage.download);
    expect(interrupted.failureKind, 'network');
    expect(interrupted.downloadedFiles, 1);
    expect(interrupted.reusedFiles, 1);
    expect(interrupted.totalFiles, 3);
    expect(interrupted.activeManifestId, releaseN1.manifestId);

    // Restart while offline: a fresh store and synchronizer on the same disk.
    final FileRuntimeContentStore restartedStore = diskStore();
    source.manifestFailure = const NetworkFailure();
    final RuntimeContentSynchronizer offline = RuntimeContentSynchronizer(
      source: source,
      store: restartedStore,
      limits: const RuntimeContentLimits(maxAttempts: 1),
      delay: (_) async {},
      telemetry: telemetry,
    );
    await expectLater(
      offline.sync(ownerId: owner),
      throwsA(isA<RuntimeContentSyncException>()),
    );
    final CachedPublicContentFile? servedOffline = await restartedStore.readActiveFile(
      runtimeContentScopeKey(owner),
      stable.id,
    );
    expect(servedOffline!.publicManifestId, releaseN1.manifestId);
    expect(servedOffline.bytes, stable.bytes);
    expect(telemetry.syncs.last.failureStage, RuntimeContentFailureStage.manifest);
    await offline.dispose();

    // Connection back: only the file that never arrived is downloaded.
    source
      ..manifestFailure = null
      ..failFilesAfter = null;
    final int requestsBeforeResume = source.fileRequests;
    final RuntimeContentSynchronizer resumed = RuntimeContentSynchronizer(
      source: source,
      store: diskStore(),
      delay: (_) async {},
      telemetry: telemetry,
    );
    final RuntimeContentSyncReport report = await resumed.sync(ownerId: owner);

    expect(report.activation.activeManifestId, releaseN.manifestId);
    expect(report.activation.previousManifestId, releaseN1.manifestId);
    expect(report.downloadedFiles, 1);
    expect(report.reusedFiles, 2);
    expect(source.fileRequests - requestsBeforeResume, 1);
    final RuntimeContentSyncEvent activated = telemetry.syncs.last;
    expect(activated.outcome, RuntimeContentSyncOutcome.activated);
    expect(activated.downloadedFiles, 1);
    expect(activated.canRollback, isTrue);
    await resumed.dispose();
  });

  test('the device cache never holds answer material after syncing a release', () async {
    final List<ContentFixture> files = <ContentFixture>[
      questionFixture('microsoft.az-900.section-1.cloud.001'),
      questionFixture('microsoft.az-900.section-1.cloud.002', prompt: 'Deuxième ?'),
    ];
    final PublicContentManifest release = manifest(files);
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: FakePublicContentSource(release, files),
      store: diskStore(),
      delay: (_) async {},
    );

    await synchronizer.sync(ownerId: owner);
    await synchronizer.dispose();

    final List<File> written = await root
        .list(recursive: true)
        .where((FileSystemEntity entity) => entity is File)
        .cast<File>()
        .toList();
    expect(written, isNotEmpty);
    expect(await _scanDeviceCache(root), isEmpty);
  });

  test('a published payload carrying an answer key is refused and never cached', () async {
    final ContentFixture safe = questionFixture('microsoft.az-900.section-1.cloud.001');
    final ContentFixture leaking = jsonFixture(
      id: 'microsoft.az-900.section-1.cloud.002',
      path: 'questions/microsoft.az-900.section-1.cloud.002.json',
      resourceType: 'question',
      json: <String, dynamic>{
        ...jsonDecode(utf8.decode(questionFixture('microsoft.az-900.section-1.cloud.002').bytes))
            as Map<String, dynamic>,
        'correctOptionIds': <String>['a'],
      },
    );
    final PublicContentManifest release = manifest(<ContentFixture>[safe, leaking]);
    final _RecordingTelemetry telemetry = _RecordingTelemetry();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: FakePublicContentSource(release, <ContentFixture>[safe, leaking]),
      store: diskStore(),
      limits: const RuntimeContentLimits(maxAttempts: 1),
      delay: (_) async {},
      telemetry: telemetry,
    );

    await expectLater(
      synchronizer.sync(ownerId: owner),
      throwsA(isA<RuntimeContentSyncException>()),
    );
    await synchronizer.dispose();

    expect(await _scanDeviceCache(root), isEmpty);
    expect(await diskStore().readActivation(runtimeContentScopeKey(owner)), isNull);
    expect(telemetry.syncs.single.outcome, RuntimeContentSyncOutcome.failed);
    expect(telemetry.syncs.single.failureStage, RuntimeContentFailureStage.validation);
    expect(telemetry.syncs.single.failureKind, 'invalidContent');
  });

  test('telemetry events carry only allow-listed, content-free fields', () async {
    final ContentFixture fixture = questionFixture(
      'microsoft.az-900.section-1.cloud.001',
      prompt: 'Texte pédagogique très reconnaissable',
    );
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final _RecordingTelemetry telemetry = _RecordingTelemetry();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: FakePublicContentSource(release, <ContentFixture>[fixture]),
      store: diskStore(),
      delay: (_) async {},
      telemetry: telemetry,
    );

    await synchronizer.sync(ownerId: owner);
    await synchronizer.sync(ownerId: owner);
    await synchronizer.rollback(ownerId: owner);
    await synchronizer.dispose();

    expect(
      telemetry.syncs.map((RuntimeContentSyncEvent event) => event.outcome),
      <RuntimeContentSyncOutcome>[
        RuntimeContentSyncOutcome.activated,
        RuntimeContentSyncOutcome.unchanged,
      ],
    );
    expect(telemetry.rollbacks.single.restored, isFalse);
    final List<Map<String, Object?>> maps = <Map<String, Object?>>[
      ...telemetry.syncs.map((RuntimeContentSyncEvent event) => event.toMap()),
      ...telemetry.rollbacks.map((RuntimeContentRollbackEvent event) => event.toMap()),
    ];
    const Set<String> allowed = <String>{
      'outcome',
      'durationMs',
      'failureStage',
      'failureKind',
      'downloadedFiles',
      'reusedFiles',
      'totalFiles',
      'activeManifestId',
      'recoveredIncompleteActivation',
      'canRollback',
      'restored',
    };
    final String serialized = jsonEncode(maps);
    for (final Map<String, Object?> map in maps) {
      expect(allowed.containsAll(map.keys), isTrue, reason: '$map');
    }
    expect(serialized, isNot(contains(owner)));
    expect(serialized, isNot(contains(runtimeContentScopeKey(owner))));
    expect(serialized, isNot(contains(fixture.id)));
    expect(serialized, isNot(contains(fixture.path)));
    expect(serialized, isNot(contains('reconnaissable')));
    expect(serialized, isNot(contains(root.path)));
    expect(maps.first['activeManifestId'], release.manifestId);
  });

  test('a restored N-1 release reports a successful rollback', () async {
    final ContentFixture first = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest releaseN1 = manifest(<ContentFixture>[first]);
    final ContentFixture second = questionFixture(
      'microsoft.az-900.section-1.cloud.002',
      prompt: 'Version N ?',
    );
    final PublicContentManifest releaseN = manifest(<ContentFixture>[first, second]);
    final FakePublicContentSource source =
        FakePublicContentSource(releaseN1, <ContentFixture>[first]);
    final _RecordingTelemetry telemetry = _RecordingTelemetry();
    final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
      source: source,
      store: diskStore(),
      delay: (_) async {},
      telemetry: telemetry,
    );
    await synchronizer.sync(ownerId: owner);
    source.promote(releaseN, <ContentFixture>[first, second]);
    await synchronizer.sync(ownerId: owner);

    final RuntimeContentActivation? restored = await synchronizer.rollback(ownerId: owner);

    expect(restored!.activeManifestId, releaseN1.manifestId);
    final RuntimeContentRollbackEvent event = telemetry.rollbacks.single;
    expect(event.restored, isTrue);
    expect(event.activeManifestId, releaseN1.manifestId);
    expect(event.failureKind, isNull);
    await synchronizer.dispose();
  });

  test('a failure label is the stable failure code, never its message', () {
    expect(runtimeContentFailureKind(const NetworkFailure('secret path /x')), 'network');
    expect(runtimeContentFailureKind(const ServerFailure('boom', statusCode: 503)), 'server');
    expect(runtimeContentFailureKind(const ParseFailure()), 'parse');
  });
}
