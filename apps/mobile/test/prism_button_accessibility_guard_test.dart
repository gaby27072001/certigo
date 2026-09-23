import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/prism_fonts.dart';

/// Garde des deux défauts de `PrismButton` mesurés en livrant « Ma série ».
///
/// Elle vit dans `apps/mobile/test/` pour la raison écrite dans
/// `haptics_discipline_test.dart` : le job requis n'exécute `flutter test` que
/// dans `apps/mobile`, et une garde posée dans `packages/prism_ui/test/` y serait
/// verte et incapable de bloquer une fusion.
///
/// 1. **Troncature** — la face faisait 54 pt fixes et l'étiquette s'élidait : à
///    Dynamic Type 2× sur 390 pt, « Réparer ma série » était peint dans 233 px et
///    coupé. Une action dont le nom est amputé n'en nomme plus aucune.
/// 2. **Fusion VoiceOver** — sans `container`, l'étiquette et l'action du bouton
///    fusionnaient dans la frontière la plus proche : dans un élément de liste,
///    toute la carte (titre, texte, faits et bouton) devenait un seul bouton.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPrismFonts);

  const Size kPhone = Size(390, 844);

  /// Height of the whole control at rest: face, lip, and the focus ring's room.
  double restingHeight({required bool depth}) =>
      kPrismButtonFaceHeight + (depth ? 4 : 0) + 2 * PrismFocusRing.inset;

  Future<void> pumpButton(WidgetTester tester, Widget button, {double scale = 1}) async {
    tester.view.physicalSize = kPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: kPhone, textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.gutter),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[button]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  RenderParagraph labelOf(WidgetTester tester, String label) => tester
      .renderObjectList<RenderParagraph>(find.text(label))
      .firstWhere((RenderParagraph p) => p.text.toPlainText() == label);

  group('rien ne bouge là où l\'étiquette tient sur une ligne', () {
    testWidgets('mouvement réduit : la profondeur et l\'échelle ne s\'animent plus', (
      WidgetTester tester,
    ) async {
      // The face now sinks through a transform instead of a positioned offset.
      // Pinned here because the equivalent check in packages/prism_ui/test never
      // runs in CI.
      tester.view.physicalSize = kPhone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: PrismTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(size: kPhone, disableAnimations: true),
            child: Scaffold(body: PrismButton(label: 'Continuer', onPressed: () {})),
          ),
        ),
      );

      expect(
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
        Duration.zero,
      );
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
    });

    testWidgets('1× : 54 pt de face, comme avant', (WidgetTester tester) async {
      await pumpButton(tester, PrismButton(label: 'Continuer', onPressed: () {}));

      expect(
        tester.getSize(find.byType(PrismButton)).height,
        restingHeight(depth: true),
      );
    });

    testWidgets('1× : un bouton fantôme, sans lèvre, garde aussi sa hauteur', (
      WidgetTester tester,
    ) async {
      await pumpButton(tester, PrismButton.ghost(label: 'Plus tard', onPressed: () {}));

      expect(
        tester.getSize(find.byType(PrismButton)).height,
        restingHeight(depth: false),
      );
    });

    testWidgets('2× : une étiquette courte garde 54 pt, la page ne se décale pas', (
      WidgetTester tester,
    ) async {
      await pumpButton(tester, PrismButton(label: 'Continuer', onPressed: () {}), scale: 2);

      expect(
        tester.getSize(find.byType(PrismButton)).height,
        restingHeight(depth: true),
      );
    });

    testWidgets('sous un Center, la face épouse son libellé au lieu de remplir l\'écran', (
      WidgetTester tester,
    ) async {
      // Found in review: with `alignment:` on the face, an Align filled any
      // bounded height — under a Center the button measured 390×844.
      tester.view.physicalSize = kPhone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final double scale in <double>[1, 3]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: PrismTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(size: kPhone, textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: PrismButton(label: 'Réparer ma série', onPressed: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final double height = tester.getSize(find.byType(PrismButton)).height;
        if (scale == 1) {
          expect(height, restingHeight(depth: true));
        } else {
          expect(height, greaterThan(restingHeight(depth: true)));
          expect(height, lessThan(kPhone.height / 3), reason: 'grows with the label, no more');
        }
      }
    });
  });

  group('une étiquette trop longue passe à la ligne au lieu d\'être coupée', () {
    const String label = 'Réparer ma série';

    for (final double scale in <double>[2.0, 3.0]) {
      testWidgets('$scale× : « $label » est entier, et la face grandit', (
        WidgetTester tester,
      ) async {
        await pumpButton(
          tester,
          PrismButton(label: label, icon: Icons.restore_rounded, onPressed: () {}),
          scale: scale,
        );

        expect(tester.takeException(), isNull);
        final RenderParagraph paragraph = labelOf(tester, label);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '« $label » est coupé à $scale× — peint sur '
              '${paragraph.size.width.toStringAsFixed(1)} px.',
        );
        if (scale == 3.0) {
          // Témoin : sans croissance, l'instrument ci-dessus ne prouverait rien —
          // l'étiquette pourrait tenir parce que rien ne la contraint.
          expect(
            tester.getSize(find.byType(PrismButton)).height,
            greaterThan(restingHeight(depth: true)),
            reason: 'at 3× this label needs two lines, and the face must make room',
          );
        }
      });
    }
  });

  group('un bouton est son propre élément VoiceOver', () {
    /// A card as screens build them: text and an action inside one list item,
    /// which is the semantics boundary everything else merges into.
    Widget listItemWith(Widget action) => MaterialApp(
          theme: PrismTheme.light(),
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                PrismCard(
                  child: Column(
                    children: <Widget>[
                      const Text('Ta série reprend à 12 jours.'),
                      action,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    testWidgets('dans une carte, le bouton ne porte que son nom', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(listItemWith(PrismButton(label: 'Réparer', onPressed: () {})));

      final Finder button = find.bySemanticsLabel('Réparer');
      expect(button, findsOneWidget);
      expect(
        tester.getSemantics(button),
        containsSemantics(isButton: true, hasTapAction: true),
      );
      expect(
        find.bySemanticsLabel(RegExp('Ta série reprend')),
        findsOneWidget,
        reason: 'the card text stays readable on its own',
      );
      handle.dispose();
    });

    testWidgets('témoin : sans conteneur, la même carte fusionne en un seul bouton', (
      WidgetTester tester,
    ) async {
      // Without this control, « findsOneWidget » above could come from an
      // instrument that never sees a merge at all.
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        listItemWith(
            Semantics(button: true, label: 'Réparer', onTap: () {}, child: const SizedBox())),
      );

      expect(find.bySemanticsLabel('Réparer'), findsNothing);
      final SemanticsNode merged = tester.getSemantics(find.bySemanticsLabel(RegExp('Réparer')));
      expect(merged.label, contains('Ta série reprend'));
      expect(merged, containsSemantics(isButton: true));
      handle.dispose();
    });
  });
}
