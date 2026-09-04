import 'dart:typed_data';

import 'package:certigo/app/offline/prefs_content_release_cache_store.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _manifestId =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test('release cache journal survives a SharedPreferences restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final JsonContentReleaseCacheStore writer = prefsContentReleaseCacheStore(prefs);
    final OfflineContentFileDescriptor catalog = OfflineContentFileDescriptor(
      id: 'catalog',
      path: 'catalog/tracks.json',
      resourceType: catalogContentResourceType,
      hash: '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a',
      size: 2,
    );
    final OfflineContentManifest manifest = OfflineContentManifest.create(
      schema: offlineContentManifestV1,
      manifestId: _manifestId,
      sourceSchema: packageManifestV3,
      files: <OfflineContentFileDescriptor>[catalog],
    );
    await writer.stageManifest(manifest);
    await writer.stageFile(
      manifest: manifest,
      descriptor: catalog,
      bytes: Uint8List.fromList(<int>[123, 125]),
    );
    await writer.activate(manifest);

    final JsonContentReleaseCacheStore restarted = prefsContentReleaseCacheStore(prefs);
    final ContentReleaseCacheSelection selected = await restarted.readBest();

    expect(selected.release!.manifest.manifestId, _manifestId);
    expect(selected.release!.fileBytes(catalog), <int>[123, 125]);
    expect(
      prefs.getString('$kContentReleaseCachePrefsPrefix$contentReleaseCachePointer'),
      anyOf(contentReleaseCacheSlotA, contentReleaseCacheSlotB),
    );
  });
}
