import 'package:flutter/widgets.dart';

/// Brand icons used by Certigo, vendored from Font Awesome Free.
///
/// Only the glyphs used by the application are exposed. The font asset is
/// bundled by `prism_ui`, so consumers do not depend on Font Awesome's Dart API.
abstract final class PrismBrandIcons {
  static const String _family = 'FontAwesomeBrands';
  static const String _package = 'prism_ui';

  static const IconData android = IconData(0xf17b, fontFamily: _family, fontPackage: _package);
  static const IconData apple = IconData(0xf179, fontFamily: _family, fontPackage: _package);
  static const IconData aws = IconData(0xf375, fontFamily: _family, fontPackage: _package);
  static const IconData docker = IconData(0xf395, fontFamily: _family, fontPackage: _package);
  static const IconData github = IconData(0xf09b, fontFamily: _family, fontPackage: _package);
  static const IconData google = IconData(0xf1a0, fontFamily: _family, fontPackage: _package);
  static const IconData java = IconData(0xf4e4, fontFamily: _family, fontPackage: _package);
  static const IconData linux = IconData(0xf17c, fontFamily: _family, fontPackage: _package);
  static const IconData microsoft = IconData(0xf3ca, fontFamily: _family, fontPackage: _package);
  static const IconData node = IconData(0xf419, fontFamily: _family, fontPackage: _package);
  static const IconData python = IconData(0xf3e2, fontFamily: _family, fontPackage: _package);
}
