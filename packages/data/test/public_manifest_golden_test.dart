import 'dart:convert';
import 'dart:io';

import 'package:data/data.dart';
import 'package:test/test.dart';

/// Reads the same golden vector as
/// `backend/tests/Certigo.Api.Tests/PublicManifestGoldenVectorTests.cs`.
///
/// That test pins the bytes the .NET API emits; this one proves the real mobile
/// parser accepts them. Together they close the gap that let a serialization change
/// reject every release while both suites stayed green: neither side can pass by
/// construction, because the manifest under test is produced by the other language.
void main() {
  group('public manifest golden vector', () {
    late File golden;

    setUpAll(() {
      golden = _locateGolden();
    });

    test('is accepted by the runtime content client parser', () {
      final bytes = golden.readAsBytesSync();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      final manifest = PublicContentManifest.fromJson(json);

      expect(manifest.schema, kPackageManifestV3);
      expect(manifest.files, hasLength(3));
      expect(manifest.manifestId, 'sha256:${manifest.rootHash}');
    });

    test('exercises both present and absent optional keys', () {
      final json = jsonDecode(golden.readAsStringSync()) as Map<String, dynamic>;
      final files = (json['files']! as List<dynamic>).cast<Map<String, dynamic>>();

      expect(files.any((Map<String, dynamic> file) => file.containsKey('objective')), isTrue);
      expect(
        files.any((Map<String, dynamic> file) => !file.containsKey('objective')),
        isTrue,
        reason: 'absent optionals must be omitted, never emitted as null',
      );
    });

    test('rejects the manifest when an absent optional is emitted as null', () {
      final json = jsonDecode(golden.readAsStringSync()) as Map<String, dynamic>;
      final files = (json['files']! as List<dynamic>).cast<Map<String, dynamic>>();
      for (final Map<String, dynamic> file in files) {
        file.putIfAbsent('objective', () => null);
      }

      expect(
        () => PublicContentManifest.fromJson(json),
        throwsA(isA<FormatException>()),
        reason: 'this is the exact defect the golden vector guards against',
      );
    });
  });
}

File _locateGolden() {
  var directory = Directory.current;
  while (true) {
    final candidate = File(
      '${directory.path}/docs/contracts/runtime-content/v1/public-manifest.golden.json',
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('public-manifest.golden.json was not found.');
    }
    directory = parent;
  }
}
