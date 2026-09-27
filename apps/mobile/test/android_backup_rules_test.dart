import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde des règles de sauvegarde Android du stockage sécurisé des jetons.
///
/// `flutter_secure_storage` range la session OIDC dans des SharedPreferences
/// chiffrées avec des clés qui ne quittent pas le Keystore de l'appareil.
/// Sauvegardées puis restaurées ailleurs, elles sont illisibles
/// (« InvalidKeyException: Failed to unwrap key », README du plugin), et des
/// jetons ne doivent jamais quitter l'appareil. Décision : exclure de la
/// sauvegarde cloud et du transfert d'appareil **uniquement** les fichiers du
/// plugin ; tout le reste garde la sauvegarde par défaut.
///
/// Les noms attendus sont lus dans les sources Java du plugin effectivement
/// résolu : une montée de version qui renomme ou ajoute un fichier fait échouer
/// ce test au lieu de laisser des jetons partir en sauvegarde.
void main() {
  File resolve(String relative) {
    for (final String base in <String>['.', 'apps/mobile']) {
      final File file = File('$base/$relative');
      if (file.existsSync()) return file;
    }
    return File(relative);
  }

  String withoutComments(String xml) => xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  final RegExp exclude = RegExp(r'<exclude\s+domain="([^"]+)"\s+path="([^"]+)"\s*/>');

  Set<String> excludedSharedPreferences(String xml) {
    final Iterable<RegExpMatch> matches = exclude.allMatches(xml);
    expect(
      matches.every((RegExpMatch m) => m.group(1) == 'sharedpref'),
      isTrue,
      reason: 'seules des SharedPreferences doivent être exclues',
    );
    return matches.map((RegExpMatch m) => m.group(2)!).toSet();
  }

  /// Fichiers SharedPreferences déclarés par le plugin Android résolu.
  Set<String> pluginSharedPreferencesFiles() {
    File? config;
    for (Directory dir = Directory.current.absolute;; dir = dir.parent) {
      final File candidate = File('${dir.path}/.dart_tool/package_config.json');
      if (candidate.existsSync()) {
        config = candidate;
        break;
      }
      if (dir.parent.path == dir.path) break;
    }
    expect(config, isNotNull, reason: 'lancer `flutter pub get` avant ce test');
    final List<dynamic> packages = (jsonDecode(config!.readAsStringSync())
        as Map<String, dynamic>)['packages'] as List<dynamic>;
    final Map<String, dynamic> plugin = packages
        .cast<Map<String, dynamic>>()
        .singleWhere((Map<String, dynamic> p) => p['name'] == 'flutter_secure_storage');
    final Directory root =
        Directory.fromUri(config.uri.resolveUri(Uri.parse(plugin['rootUri'] as String)));
    final RegExp name = RegExp(r'SHARED_PREFERENCES_NAME\s*=\s*"([^"]+)"');
    final Set<String> files = <String>{};
    for (final FileSystemEntity entity
        in Directory('${root.path}/android/src/main').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.java')) {
        for (final RegExpMatch m in name.allMatches(entity.readAsStringSync())) {
          files.add('${m.group(1)}.xml');
        }
      }
    }
    return files;
  }

  test('le manifeste branche les deux fichiers de règles sans couper la sauvegarde', () {
    final File manifest = resolve('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue, reason: 'AndroidManifest.xml introuvable');
    final String application = RegExp(r'<application\b[^>]*>', dotAll: true)
        .firstMatch(withoutComments(manifest.readAsStringSync()))!
        .group(0)!;
    expect(application, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(application, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    expect(application, isNot(contains('android:allowBackup="false"')));
  });

  test('les fichiers exclus sont exactement ceux du stockage sécurisé', () {
    final Set<String> plugin = pluginSharedPreferencesFiles();
    expect(plugin, containsAll(<String>['FlutterSecureStorage.xml']));

    final String legacy = withoutComments(
        resolve('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync());
    expect(legacy, contains('<full-backup-content>'));
    expect(legacy, isNot(contains('<include')), reason: 'un <include> exclurait tout le reste');
    expect(excludedSharedPreferences(legacy), plugin);

    final String modern = withoutComments(
      resolve('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync(),
    );
    expect(modern, contains('<data-extraction-rules>'));
    expect(modern, isNot(contains('<include')), reason: 'un <include> exclurait tout le reste');
    for (final String mode in <String>['cloud-backup', 'device-transfer']) {
      final RegExpMatch? section =
          RegExp('<$mode(?:\\s[^>]*)?>(.*?)</$mode>', dotAll: true).firstMatch(modern);
      expect(section, isNotNull, reason: 'sans section <$mode>, ce mode sauvegarde tout');
      expect(excludedSharedPreferences(section!.group(1)!), plugin, reason: mode);
    }
  });
}
