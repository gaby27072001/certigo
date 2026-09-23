import 'dart:convert';
import 'dart:io';

import 'package:certigo/app/content/runtime_content_providers.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String _questionId = 'microsoft.az-900.section-1.cloud.001';
const String _manifestId =
    'sha256:6f6dc9baf4630c51fdd74723418842ccbb20eb03424ab65be7d994b3378457d7';
const String _releaseId = 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _questionJson =
    '{"id":"microsoft.az-900.section-1.cloud.001","schemaVersion":"v4","kind":"public",'
    '"metadata":{"provider":"microsoft","certification":"microsoft:az-900",'
    '"blueprintVersion":"2026-08-17","objective":"section-1",'
    '"domainId":"microsoft.az-900.domain.cloud-concepts",'
    '"conceptId":"microsoft.az-900.concept.cloud-service-models"},'
    '"itemType":"mcq","difficulty":1,"prompt":"Question publique ?",'
    '"options":[{"id":"a","label":"A"},{"id":"b","label":"B"}]}\n';

PublicContentManifest _manifest() => PublicContentManifest.fromJson(<String, dynamic>{
      'schema': kPackageManifestV3,
      'channel': 'public',
      'artifact': 'public',
      'algorithm': 'sha256',
      'serialization': 'json-sorted-keys-compact-utf8-lf',
      'fileCount': 1,
      'files': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': _questionId,
          'path': 'questions/$_questionId.json',
          'resourceType': 'question',
          'hash': 'e0208cbc620674d92ea5ee2089b552f9bf59c2254c63a741fb3e523dfd96c19b',
          'size': 443,
        },
      ],
      'manifestId': _manifestId,
      'rootHash': _manifestId.substring(7),
      'releaseId': _releaseId,
    });

class _Source implements PublicContentSource {
  _Source(this.manifest);

  final PublicContentManifest manifest;
  int downloads = 0;

  @override
  Future<Result<PublicManifestFetch>> fetchActiveManifest({
    String? ifNoneMatch,
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  }) async {
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
    downloads++;
    return Success<PublicContentFileFetch>(
      PublicContentFileFetch.fetched(
        bytes: Uint8List.fromList(utf8.encode(_questionJson)),
        etag: '"sha256:${file.hash}"',
        releaseId: releaseId,
        publicManifestId: publicManifestId,
        resourceType: file.resourceType,
      ),
    );
  }
}

class _RecordingTelemetry implements RuntimeContentTelemetry {
  final List<RuntimeContentSyncEvent> syncs = <RuntimeContentSyncEvent>[];

  @override
  void syncFinished(RuntimeContentSyncEvent event) => syncs.add(event);

  @override
  void rollbackFinished(RuntimeContentRollbackEvent event) {}
}

void main() {
  // Host-level twin of integration_test/runtime_content_sync_test.dart: the same
  // restart scenario through the app's own providers and the real disk store, so
  // CI proves the flag-on composition even without a device.
  test('app composition syncs to disk, survives a restart and reports telemetry', () async {
    final Directory root = await Directory.systemTemp.createTemp('certigo-mobile-runtime-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final _Source source = _Source(_manifest());
    final _RecordingTelemetry telemetry = _RecordingTelemetry();
    ProviderContainer app() {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          runtimeContentSyncEnabledProvider.overrideWithValue(true),
          runtimeContentStoreProvider.overrideWithValue(
            FileRuntimeContentStore(root: root, spaceScope: 'mobile-host'),
          ),
          runtimeContentSourceProvider.overrideWithValue(source),
          runtimeContentTelemetryProvider.overrideWithValue(telemetry),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    final RuntimeContentSynchronizer first = app().read(runtimeContentSynchronizerProvider);
    await first.sync(ownerId: 'person-1');
    await first.dispose();

    final ProviderContainer restarted = app();
    final RuntimeContentSynchronizer second = restarted.read(runtimeContentSynchronizerProvider);
    final RuntimeContentSyncReport report = await second.sync(ownerId: 'person-1');
    final CachedPublicContentFile? cached =
        await restarted.read(runtimeContentStoreProvider).readActiveFile(
              runtimeContentScopeKey('person-1'),
              _questionId,
            );
    await second.dispose();

    expect(report.changed, isFalse);
    expect(source.downloads, 1);
    expect(cached!.publicManifestId, _manifestId);
    expect(utf8.decode(cached.bytes), _questionJson);
    expect(
      telemetry.syncs.map((RuntimeContentSyncEvent event) => event.outcome),
      <RuntimeContentSyncOutcome>[
        RuntimeContentSyncOutcome.activated,
        RuntimeContentSyncOutcome.unchanged,
      ],
    );
  });

  test('debug telemetry prints only the allow-listed event map', () {
    final List<String> lines = <String>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
    addTearDown(() => debugPrint = original);

    const DebugRuntimeContentTelemetry().syncFinished(
      const RuntimeContentSyncEvent(
        outcome: RuntimeContentSyncOutcome.failed,
        durationMs: 12,
        failureStage: RuntimeContentFailureStage.download,
        failureKind: 'network',
        activeManifestId: _manifestId,
      ),
    );

    expect(lines, hasLength(1));
    expect(lines.single, startsWith('[runtime-content] sync {'));
    final Map<String, dynamic> printed =
        jsonDecode(lines.single.substring('[runtime-content] sync '.length))
            as Map<String, dynamic>;
    expect(printed['failureStage'], 'download');
    expect(printed['failureKind'], 'network');
    expect(printed.keys, containsAll(<String>['outcome', 'durationMs', 'activeManifestId']));
  });

  test('release builds keep the telemetry sink silent by default', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(runtimeContentTelemetryProvider),
      kDebugMode ? isA<DebugRuntimeContentTelemetry>() : isA<NoopRuntimeContentTelemetry>(),
    );
  });
}
