import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde structurelle : un **aplat** ne prend jamais le rôle de premier plan.
///
/// Pourquoi ce test existe — la régression qu'il ferme :
///
/// Les tokens d'accent existent en deux rôles opposés. Le nom nu (`p.primary`)
/// est le rôle de **premier plan** : il s'adapte au thème, et s'éclaircit donc
/// en mode sombre. Le rôle `*Fill` est l'**aplat** : il reste stable, parce
/// qu'un aplat porte du texte blanc.
///
/// Confondre les deux ne casse rien à la compilation et ne se voit pas en mode
/// clair, où les deux rôles coïncident. En mode sombre, un aplat qui prend le
/// rôle de premier plan met du blanc sur une couleur claire : le CTA de l'écran
/// d'ouverture est tombé à **2.73:1** de cette façon, là où le rôle d'aplat
/// donne 7.05:1.
///
/// Le contraste seul ne suffit pas à l'attraper : `prism_contrast_contract_test`
/// vérifie que chaque *rôle* est correct, pas que chaque *site d'appel* choisit
/// le bon. C'est ce que fait ce fichier, en lisant la source.
void main() {
  const List<String> accents = <String>[
    'primary',
    'ember',
    'xpGold',
    'success',
    'warning',
    'error',
    'info',
  ];

  /// `colors: <Color>[p.primary, …]` — un dégradé opaque est un aplat par
  /// définition. La forme alpha (`p.primary.withOpacity(…)`) en est exclue :
  /// c'est un lavis posé sur le chrome, pas une surface qui porte du texte.
  final RegExp gradientList = RegExp(
    r'colors:\s*<Color>\[[^\]]*?\b\w+\.(' +
        accents.join('|') +
        r')\b(?!Fill|Vivid|OnSurface|Soft|\s*\.with)',
    multiLine: true,
  );

  List<File> dartSources(String root) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  test('aucun dégradé ne peint un accent dans le rôle de premier plan', () {
    final List<String> offenders = <String>[];
    for (final String root in <String>['../../apps/mobile/lib', 'lib']) {
      if (!Directory(root).existsSync()) continue;
      for (final File file in dartSources(root)) {
        final String source = file.readAsStringSync();
        for (final RegExpMatch m in gradientList.allMatches(source)) {
          final int line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          offenders.add('${file.path}:$line  ${m.group(0)!.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Un dégradé est un aplat : il porte du texte et doit donc prendre le rôle '
          '`*Fill`, stable entre les thèmes. Le rôle nu s\'éclaircit en mode sombre et '
          'fait tomber le texte blanc sous le seuil.\n${offenders.join('\n')}',
    );
  });

  test('le rôle d\'aplat existe pour chaque accent', () {
    // Si un accent perdait son rôle `*Fill`, la garde ci-dessus deviendrait
    // impossible à satisfaire et quelqu'un la contournerait.
    final String scheme = File('lib/src/theme/prism_color_scheme.dart').readAsStringSync();
    for (final String accent in accents) {
      expect(
        scheme,
        contains('${accent}Fill'),
        reason: '$accent doit exposer un rôle d\'aplat',
      );
    }
    expect(scheme, contains('domainAccentsFill'));
    expect(scheme, contains('accentFillFor'));
  });
}
