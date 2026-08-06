import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  test('brand glyphs resolve from the vendored Prism font', () {
    const List<IconData> icons = <IconData>[
      PrismBrandIcons.android,
      PrismBrandIcons.apple,
      PrismBrandIcons.aws,
      PrismBrandIcons.docker,
      PrismBrandIcons.github,
      PrismBrandIcons.google,
      PrismBrandIcons.java,
      PrismBrandIcons.linux,
      PrismBrandIcons.microsoft,
      PrismBrandIcons.node,
      PrismBrandIcons.python,
    ];

    for (final IconData icon in icons) {
      expect(icon.fontFamily, 'FontAwesomeBrands');
      expect(icon.fontPackage, 'prism_ui');
      expect(icon.codePoint, isPositive);
    }
  });
}
