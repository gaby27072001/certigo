import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _questionId = 'microsoft.az-900.section-1.cloud.001';
const String _manifestId =
    'sha256:6f6dc9baf4630c51fdd74723418842ccbb20eb03424ab65be7d994b3378457d7';
const String _questionJson =
    '{"id":"microsoft.az-900.section-1.cloud.001","schemaVersion":"v4","kind":"public",'
    '"metadata":{"provider":"microsoft","certification":"microsoft:az-900",'
    '"blueprintVersion":"2026-08-17","objective":"section-1",'
    '"domainId":"microsoft.az-900.domain.cloud-concepts",'
    '"conceptId":"microsoft.az-900.concept.cloud-service-models"},'
    '"itemType":"mcq","difficulty":1,"prompt":"Question publique ?",'
    '"options":[{"id":"a","label":"A"},{"id":"b","label":"B"}]}\n';

class _IntegrationSource implements PublicContentSource {
  _IntegrationSource(this.manifest);

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
          ? PublicManifestFetch.notModified(etag)
          : PublicManifestFetch.fetched(manifest, etag),
    );
  }

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String publicManifestId,
    required PublicContentFile file,
  }) async {
    downloads++;
    return Success<PublicContentFileFetch>(
      PublicContentFileFetch(
        bytes: Uint8List.fromList(utf8.encode(_questionJson)),
        etag: '"${file.hash}"',
        publicManifestId: publicManifestId,
        resourceType: file.resourceType,
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manifest sync survives restart and reuses the atomic activation', (
    WidgetTester tester,
  ) async {
    final Directory root = await Directory.systemTemp.createTemp('certigo-content-e2e-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final PublicContentManifest manifest = PublicContentManifest.fromJson(
      <String, dynamic>{
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
      },
    );
    final _IntegrationSource source = _IntegrationSource(manifest);
    final FileRuntimeContentStore store = FileRuntimeContentStore(
      root: root,
      spaceScope: 'integration',
    );
    final RuntimeContentSynchronizer first = RuntimeContentSynchronizer(
      source: source,
      store: store,
      delay: (_) async {},
    );
    await first.sync(ownerId: 'person-1');
    await first.dispose();

    final RuntimeContentSynchronizer restarted = RuntimeContentSynchronizer(
      source: source,
      store: FileRuntimeContentStore(root: root, spaceScope: 'integration'),
      delay: (_) async {},
    );
    final RuntimeContentSyncReport report = await restarted.sync(ownerId: 'person-1');
    final CachedPublicContentFile? cached = await store.readActiveFile(
      runtimeContentScopeKey('person-1'),
      _questionId,
    );

    expect(report.changed, isFalse);
    expect(source.downloads, 1);
    expect(cached!.publicManifestId, _manifestId);
    expect(utf8.decode(cached.bytes), _questionJson);
    await restarted.dispose();
  });
}
