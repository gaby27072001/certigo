import 'dart:io';
import 'dart:ui' as ui;

/// Charge les **vraies** polices Prism dans le harnais de test.
///
/// Sans cela, `flutter_test` dessine chaque glyphe comme un carré plein de la
/// taille de la fonte. Toute mesure typographique est alors une fiction : un
/// nom de 65 caractères réclame 5 lignes dans 324 px avec la police de test,
/// contre 3 avec Archivo. Une garde de reflow calibrée sur la police de test
/// mesurerait donc un écran qui n'existe pas.
///
/// Le nom de famille doit être celui que Flutter **résout**, pas celui déclaré
/// dans le `pubspec` : un `TextStyle(fontFamily: 'Archivo', package: 'prism_ui')`
/// demande au moteur la famille `packages/prism_ui/Archivo`.
///
/// Les icônes Material viennent du SDK, pas du dépôt : sans elles chaque
/// pictogramme se dessine en carré vide et fausse la largeur des lignes qui en
/// contiennent.
Future<void> loadPrismFonts() async {
  const String prismAssets = '../../packages/prism_ui/assets/fonts';
  for (final MapEntry<String, String> font in <String, String>{
    'packages/prism_ui/Archivo': 'Archivo-Variable.ttf',
    'packages/prism_ui/Inter': 'Inter-Variable.ttf',
    'packages/prism_ui/JetBrainsMono': 'JetBrainsMono-Variable.ttf',
    'packages/prism_ui/PlusJakartaSans': 'PlusJakartaSans-Variable.ttf',
  }.entries) {
    final File file = File('$prismAssets/${font.value}');
    if (!file.existsSync()) continue;
    await ui.loadFontFromList(file.readAsBytesSync(), fontFamily: font.key);
  }
  final String? sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk == null) return;
  final File icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await ui.loadFontFromList(icons.readAsBytesSync(), fontFamily: 'MaterialIcons');
  }
}
