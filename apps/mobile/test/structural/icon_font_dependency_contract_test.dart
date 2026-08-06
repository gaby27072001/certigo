import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Prism exclusively owns the icon and font dependencies', () {
    final String appPubspec = File('pubspec.yaml').readAsStringSync();
    final String prismPubspec =
        File('../../packages/prism_ui/pubspec.yaml').readAsStringSync();
    final String prismLock =
        File('../../packages/prism_ui/pubspec.lock').readAsStringSync();
    final File checksums =
        File('../../packages/prism_ui/assets/fonts/SHA256SUMS');
    final List<File> fontAssets = <File>[
      File('../../packages/prism_ui/assets/fonts/PlusJakartaSans-Variable.ttf'),
      File('../../packages/prism_ui/assets/fonts/Inter-Variable.ttf'),
      File('../../packages/prism_ui/assets/fonts/JetBrainsMono-Variable.ttf'),
      File('../../packages/prism_ui/assets/fonts/FontAwesomeBrands-400.ttf'),
    ];

    expect(appPubspec, isNot(contains('\n  google_fonts:')));
    expect(appPubspec, isNot(contains('\n  font_awesome_flutter:')));
    expect(appPubspec, contains('\n  prism_ui:'));

    expect(prismPubspec, isNot(contains('\n  google_fonts:')));
    expect(prismLock, isNot(contains('name: google_fonts')));
    for (final File asset in fontAssets) {
      expect(asset.existsSync(), isTrue,
          reason: '${asset.path} must be bundled');
      expect(asset.lengthSync(), greaterThan(100000));
      expect(prismPubspec, contains(asset.uri.pathSegments.last));
    }
    expect(checksums.existsSync(), isTrue);
    expect(checksums.readAsLinesSync(), hasLength(4));
  });
}
