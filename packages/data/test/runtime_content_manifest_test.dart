import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

import 'runtime_content_test_support.dart';

void main() {
  group('PublicContentManifest', () {
    test('accepts the exact public package v3 contract', () {
      final ContentFixture question = questionFixture('microsoft.az-900.section-1.cloud.001');

      final PublicContentManifest parsed = manifest(<ContentFixture>[question]);

      expect(parsed.schema, kPackageManifestV3);
      expect(parsed.files.single.resourceType, 'question');
      expect(parsed.manifestId, startsWith('sha256:'));
    });

    test('rejects a private channel before any file is accepted', () {
      final ContentFixture question = questionFixture('microsoft.az-900.section-1.cloud.001');
      final Map<String, dynamic> json = manifestJson(<ContentFixture>[question]);
      json['channel'] = 'answerKey';

      expect(() => PublicContentManifest.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('rejects path traversal and duplicate ids', () {
      final ContentFixture question = questionFixture('microsoft.az-900.section-1.cloud.001');
      final Map<String, dynamic> unsafe = manifestJson(<ContentFixture>[question]);
      (unsafe['files'] as List<dynamic>).single['path'] = '../solutions/key.json';

      expect(() => PublicContentManifest.fromJson(unsafe), throwsA(isA<FormatException>()));
    });
  });

  group('validatePublicContentPayload', () {
    test('verifies size, hash, identity and public schema', () {
      final ContentFixture question = questionFixture('microsoft.az-900.section-1.cloud.001');
      final PublicContentFile file = manifest(<ContentFixture>[question]).files.single;

      final Map<String, dynamic> payload = validatePublicContentPayload(file, question.bytes);

      expect(payload['kind'], 'public');
      expect(payload, isNot(contains('correctOptionIds')));
    });

    test('rejects recursively leaked rationale', () {
      final ContentFixture question = questionFixture('microsoft.az-900.section-1.cloud.001');
      final Map<String, dynamic> leaked = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(question.bytes)) as Map,
      );
      leaked['metadata'] = <String, dynamic>{
        ...(leaked['metadata'] as Map<String, dynamic>),
        'rationale': 'secret',
      };
      final Uint8List bytes = Uint8List.fromList(utf8.encode('${jsonEncode(leaked)}\n'));
      final PublicContentFile file = PublicContentFile(
        id: question.id,
        path: question.path,
        resourceType: question.resourceType,
        hash: sha256.convert(bytes).toString(),
        size: bytes.length,
      );

      expect(() => validatePublicContentPayload(file, bytes), throwsA(isA<FormatException>()));
    });

    test('rejects recursively leaked releaseId', () {
      final ContentFixture question = questionFixture('microsoft.az-900.section-1.cloud.001');
      final Map<String, dynamic> leaked = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(question.bytes)) as Map,
      );
      leaked['metadata'] = <String, dynamic>{
        ...(leaked['metadata'] as Map<String, dynamic>),
        'releaseId': 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      };
      final Uint8List bytes = Uint8List.fromList(utf8.encode('${jsonEncode(leaked)}\n'));
      final PublicContentFile file = PublicContentFile(
        id: question.id,
        path: question.path,
        resourceType: question.resourceType,
        hash: sha256.convert(bytes).toString(),
        size: bytes.length,
      );

      expect(() => validatePublicContentPayload(file, bytes), throwsA(isA<FormatException>()));
    });
  });
}
