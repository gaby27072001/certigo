import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde de **comportement natif** du défilement.
///
/// Le rebond élastique est la physique **iOS**. Android, lui, montre un
/// étirement lumineux (`StretchingOverscrollIndicator`) et s'arrête net en fin
/// de liste. Coder `BouncingScrollPhysics` en dur impose donc le geste iOS aux
/// utilisateurs Android — c'est exactement le marqueur qui fait qu'une
/// application « ne se sent pas native » sur la plateforme lésée.
///
/// Flutter fait déjà le bon choix tout seul : `MaterialScrollBehavior` résout la
/// physique selon `Theme.of(context).platform`. La bonne pratique est donc de
/// **ne pas** passer `physics:` du tout. Ces tests vérifient les deux moitiés :
/// que la résolution automatique donne bien la physique de chaque plateforme, et
/// que personne ne réintroduit un rebond figé.
void main() {
  group('physique de défilement par plateforme', () {
    /// Récupère la physique que la plateforme demandée résout réellement.
    ///
    /// On interroge `ScrollConfiguration` plutôt que `Scrollable.physics` :
    /// `ListView` passe sa propre `AlwaysScrollableScrollPhysics` au
    /// `Scrollable`, ce qui masque la chaîne de plateforme. C'est
    /// `ScrollBehavior.getScrollPhysics` qui porte la décision iOS/Android.
    ///
    /// `debugDefaultTargetPlatformOverride` permet de tester le comportement iOS
    /// depuis Windows : même mécanique que `back_swipe_gesture_test.dart`.
    Future<ScrollPhysics> physicsFor(
      WidgetTester tester,
      TargetPlatform platform,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        late ScrollPhysics resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Builder(
              builder: (BuildContext context) {
                resolved = ScrollConfiguration.of(context).getScrollPhysics(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        return resolved;
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('iOS obtient le rebond élastique', (WidgetTester tester) async {
      final ScrollPhysics physics = await physicsFor(tester, TargetPlatform.iOS);
      expect(
        physics.toString(),
        contains('BouncingScrollPhysics'),
        reason: 'Sans rebond, une liste iOS se sent morte en fin de course.',
      );
    });

    testWidgets('Android obtient la physique bornée, pas le rebond iOS',
        (WidgetTester tester) async {
      final ScrollPhysics physics = await physicsFor(tester, TargetPlatform.android);
      expect(
        physics.toString(),
        contains('ClampingScrollPhysics'),
        reason: 'Android doit buter en fin de liste et montrer un étirement.',
      );
      expect(
        physics.toString(),
        isNot(contains('BouncingScrollPhysics')),
        reason: 'Le rebond est un geste iOS : sur Android il trahit le portage.',
      );
    });
  });

  group('aucune physique iOS figée dans le code', () {
    /// `NeverScrollableScrollPhysics` (désactiver un défilement imbriqué) et
    /// `FixedExtentScrollPhysics` (roue de sélection) sont légitimes : ils
    /// expriment une intention, pas une plateforme. Seul le rebond figé est
    /// interdit, parce qu'il en désigne une.
    test('BouncingScrollPhysics n\'est codé en dur nulle part', () {
      final List<Directory> roots = <Directory>[
        for (final String path in <String>[
          'lib',
          '../../apps/mobile/lib',
          '../../packages/prism_ui/lib',
          'packages/prism_ui/lib',
          'apps/mobile/lib',
        ])
          Directory(path),
      ].where((Directory d) => d.existsSync()).toList();

      expect(roots, isNotEmpty, reason: 'Aucune racine de code résolue.');

      final List<String> offenders = <String>[];
      for (final Directory root in roots) {
        for (final FileSystemEntity entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final List<String> lines = entity.readAsLinesSync();
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].contains('BouncingScrollPhysics')) {
              offenders.add('${entity.path}:${i + 1}');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Retirer « physics: » laisse ScrollBehavior choisir la physique '
            'de la plateforme. Sites fautifs :\n${offenders.join('\n')}',
      );
    });
  });
}
