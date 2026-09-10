import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Prism exclusively owns the icon and font dependencies', () {
    final String appPubspec = File('pubspec.yaml').readAsStringSync();
    final String appLock = File('pubspec.lock').readAsStringSync();
    final String prismPubspec = File('../../packages/prism_ui/pubspec.yaml').readAsStringSync();
    final String prismLock = File('../../packages/prism_ui/pubspec.lock').readAsStringSync();
    final File checksums = File('../../packages/prism_ui/assets/fonts/SHA256SUMS');
    final List<File> fontAssets = <File>[
      File('../../packages/prism_ui/assets/fonts/Archivo-Variable.ttf'),
      File('../../packages/prism_ui/assets/fonts/PlusJakartaSans-Variable.ttf'),
      File('../../packages/prism_ui/assets/fonts/Inter-Variable.ttf'),
      File('../../packages/prism_ui/assets/fonts/JetBrainsMono-Variable.ttf'),
      File('../../packages/prism_ui/assets/fonts/FontAwesomeBrands-400.ttf'),
    ];

    expect(appPubspec, isNot(contains('\n  google_fonts:')));
    expect(appPubspec, isNot(contains('\n  font_awesome_flutter:')));
    expect(appPubspec, contains('\n  prism_ui:'));
    expect(appLock, isNot(contains('name: google_fonts')));
    expect(appLock, isNot(contains('name: font_awesome_flutter')));
    expect(appLock, contains('dart: ">=3.12.2 <4.0.0"'));
    expect(appLock, contains('flutter: ">=3.44.4"'));

    expect(prismPubspec, isNot(contains('\n  google_fonts:')));
    expect(prismLock, isNot(contains('name: google_fonts')));
    expect(prismLock, contains('dart: ">=3.12.2 <4.0.0"'));
    expect(prismLock, contains('flutter: ">=3.44.4"'));
    for (final File asset in fontAssets) {
      expect(asset.existsSync(), isTrue, reason: '${asset.path} must be bundled');
      expect(asset.lengthSync(), greaterThan(100000));
      expect(prismPubspec, contains(asset.uri.pathSegments.last));
    }
    expect(checksums.existsSync(), isTrue);
    // Derived from the asset list so a newly bundled face cannot slip in
    // unchecksummed.
    expect(checksums.readAsLinesSync(), hasLength(fontAssets.length));
    for (final File asset in fontAssets) {
      expect(
        checksums.readAsStringSync(),
        contains(asset.uri.pathSegments.last),
        reason: '${asset.uri.pathSegments.last} must be checksummed',
      );
    }
    // Every bundled face ships its licence.
    for (final String licence in <String>[
      'Archivo-OFL.txt',
      'Inter-OFL.txt',
      'JetBrainsMono-OFL.txt',
      'PlusJakartaSans-OFL.txt',
      'FontAwesome-Free-LICENSE.txt',
    ]) {
      expect(
        File('../../packages/prism_ui/assets/fonts/licenses/$licence').existsSync(),
        isTrue,
        reason: '$licence must ship with the font',
      );
    }
  });

  test('Flutter and Dart pins stay aligned across CI and releases', () {
    final String ciMobile = File('../../.github/workflows/ci-mobile.yml').readAsStringSync();
    final String cortexParity = File(
      '../../.github/workflows/ci-cortex-parity.yml',
    ).readAsStringSync();
    final String androidRelease = File(
      '../../.github/workflows/release-android.yml',
    ).readAsStringSync();
    final String iosRelease = File('../../.github/workflows/release-ios.yml').readAsStringSync();
    final String codemagic = File('../../codemagic.yaml').readAsStringSync();

    expect(ciMobile, contains('FLUTTER_VERSION: "3.44.4"'));
    expect(ciMobile, contains('sdk: "3.12.2"'));
    expect(ciMobile, isNot(contains('FLUTTER_VERSION: "3.27.4"')));
    expect(ciMobile, isNot(contains('FLUTTER_VERSION: "3.44.5"')));
    expect(cortexParity, contains('sdk: "3.12.2"'));
    expect(androidRelease, contains('FLUTTER_VERSION: "3.44.4"'));
    expect(iosRelease, contains('FLUTTER_VERSION: "3.44.4"'));
    expect('flutter: 3.44.4'.allMatches(codemagic), hasLength(3));
  });

  test('PR CI cannot access Sentry symbol upload credentials or commands', () {
    final String githubWorkflows = Directory('../../.github/workflows')
        .listSync()
        .whereType<File>()
        .map((File file) => file.readAsStringSync())
        .join('\n');
    final String codemagic = File('../../codemagic.yaml').readAsStringSync();

    expect(githubWorkflows, isNot(contains('SENTRY_AUTH_TOKEN')));
    expect(githubWorkflows, isNot(contains('sentry_dart_plugin')));
    expect(githubWorkflows, isNot(contains('debug-files upload')));
    expect(githubWorkflows, isNot(contains('upload_debug_symbols')));

    expect(RegExp(r'\$\{SENTRY_AUTH_TOKEN:-\}').allMatches(codemagic), hasLength(1));
    expect(codemagic, contains('name: Upload and archive iOS dSYMs (blocking)'));
    expect(codemagic, isNot(contains('--auth-token')));
  });
}
