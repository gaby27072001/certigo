import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde de casse : un libellé de bouton s'écrit en casse de phrase.
///
/// Pourquoi ce test existe :
///
/// L'application portait deux conventions en même temps. L'écran d'ouverture
/// disait « Commencer », l'écran suivant « CONTINUER ». Quatorze libellés
/// d'action étaient en capitales, le reste en casse de phrase — donc la
/// bascule se produisait au premier pas du tunnel d'inscription, sur l'action
/// principale, à l'endroit le plus visible du parcours.
///
/// Ce n'est pas une question de goût : deux vocabulaires pour la même classe
/// d'action obligent l'œil à ré-apprendre le contrôle d'un écran à l'autre.
///
/// La garde ne vise que les **libellés d'action** (`label`, `primaryLabel`,
/// `startLabel`). Les petites étiquettes de section en capitales — « BANQUE DE
/// MOTS », « ZONE DE PROMOTION » — sont un procédé typographique délibéré :
/// `labelSmall`, graisse 800 et interlettrage ouvert. Elles sont une autre
/// catégorie et restent autorisées.
void main() {
  test('aucun libellé d\'action n\'est en capitales', () {
    // Deux mots en capitales ou plus, ou un mot d'au moins quatre lettres :
    // assez large pour attraper « CONTINUER » et « COMMENCER CE PARCOURS »,
    // assez étroit pour laisser passer « XP », « IaaS » ou « AZ-900 ».
    final RegExp shoutingLabel = RegExp(
      r"\b(?:primaryLabel|startLabel|label)\s*:\s*'([A-ZÉÈÀÇÊÎÔÛ]{4,}(?:\s+[A-ZÉÈÀÇÊÎÔÛ]+)*)'",
    );

    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final String source = entity.readAsStringSync();
      for (final RegExpMatch m in shoutingLabel.allMatches(source)) {
        final int line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        offenders.add('${entity.path}:$line  ${m.group(1)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Un libellé d\'action s\'écrit en casse de phrase — « Continuer », pas '
          '« CONTINUER » — pour que le même geste porte le même nom d\'un écran à '
          'l\'autre.\n${offenders.join('\n')}',
    );
  });

  test('l\'action principale porte le même nom partout', () {
    // Contrôle positif : la garde ci-dessus resterait verte si tous les
    // libellés disparaissaient. Celui-ci vérifie que la forme attendue est
    // bien celle qui est employée.
    final String landing =
        File('lib/features/auth/presentation/landing_screen.dart').readAsStringSync();
    final String onboarding =
        File('lib/features/onboarding/presentation/goal_screen.dart').readAsStringSync();
    expect(landing, contains("'Commencer'"));
    expect(onboarding, contains("'Continuer'"));
  });
}
