import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Garde de **comportement natif** : la taille des zones tactiles.
///
/// Les *Human Interface Guidelines* d'Apple fixent 44×44 pt comme la plus
/// petite cible qu'un doigt atteint de façon fiable. Une cible en dessous est
/// l'un des défauts « non natifs » les plus immédiatement ressentis : le
/// contrôle est visible, on appuie, et il ne se passe rien.
///
/// Flutter applique déjà ce plancher à ses propres boutons
/// (`MaterialTapTargetSize.padded`, et `PrismTheme` le demande). Mais **rien**
/// ne l'applique à un `GestureDetector` nu, qui adopte simplement la taille de
/// ce qu'il entoure — une icône de 20 pt donne une cible de 20 pt.
///
/// ## Pourquoi l'arbre d'éléments et pas la sémantique
///
/// Une première version de cette mesure parcourait l'arbre de **sémantique**.
/// Elle voyait le chevron de retour de l'onboarding (34×34) mais **ratait
/// silencieusement** le bouton info de `UnitHeader` (20×20), parce qu'un
/// `Semantics` parent fusionne ses descendants en un seul nœud : le bouton
/// disparaissait dans un nœud de 390×82 qui, lui, passait.
///
/// Cette version parcourt l'**arbre d'éléments** et mesure le `RenderBox` de
/// chaque détecteur de gestes. Elle ne dépend d'aucune fusion.
void main() {
  /// Mesure toute cible tactile sous [child] et rend les manquements.
  Future<List<String>> undersizedTargets(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final List<String> offenders = <String>[];
    void visit(Element el) {
      final Widget w = el.widget;
      final bool tappable = switch (w) {
        GestureDetector(:final VoidCallback? onTap) => onTap != null,
        InkResponse(:final VoidCallback? onTap) => onTap != null,
        _ => false,
      };
      if (tappable) {
        final RenderObject? ro = el.renderObject;
        if (ro is RenderBox && ro.hasSize) {
          final Size s = ro.size;
          if (s.width < kPrismMinTapTarget || s.height < kPrismMinTapTarget) {
            offenders.add('${w.runtimeType} '
                '${s.width.toStringAsFixed(1)}x${s.height.toStringAsFixed(1)}');
          }
        }
      }
      el.visitChildren(visit);
    }

    tester.binding.rootElement!.visitChildren(visit);
    return offenders;
  }

  group('l\'instrument sait varier', () {
    // Sans ces trois témoins, une liste vide de manquements ne prouverait rien :
    // elle serait indiscernable d'une sonde qui ne lit rien.
    // Voir docs/GOVERNANCE.md §7c — « le contrôle qui rend une présence ».
    testWidgets('ne voit rien là où il n\'y a rien à toucher', (WidgetTester tester) async {
      expect(await undersizedTargets(tester, const Text('inerte')), isEmpty);
    });

    testWidgets('ignore un détecteur sans onTap', (WidgetTester tester) async {
      expect(
        await undersizedTargets(tester, GestureDetector(child: const Text('inerte'))),
        isEmpty,
      );
    });

    testWidgets('attrape une cible trop petite', (WidgetTester tester) async {
      final List<String> found = await undersizedTargets(
        tester,
        GestureDetector(onTap: () {}, child: const SizedBox(width: 10, height: 10)),
      );
      expect(found, hasLength(1));
      expect(found.single, contains('10.0x10.0'));
    });

    testWidgets('laisse passer une cible assez grande', (WidgetTester tester) async {
      expect(
        await undersizedTargets(
          tester,
          GestureDetector(onTap: () {}, child: const SizedBox(width: 60, height: 60)),
        ),
        isEmpty,
      );
    });
  });

  group('les contrôles Prism atteignent le plancher d\'Apple', () {
    final Map<String, Widget> surfaces = <String, Widget>{
      'OnboardingScaffold — chevron de retour': OnboardingScaffold(
        primaryLabel: 'Continuer',
        onPrimary: () {},
        progress: 0.4,
        onBack: () {},
        child: const Text('contenu'),
      ),
      'OnboardingScaffold — croix de fermeture': OnboardingScaffold(
        primaryLabel: 'Continuer',
        onPrimary: () {},
        progress: 0.4,
        onClose: () {},
        child: const Text('contenu'),
      ),
      'UnitHeader — bouton info': UnitHeader(
        index: 1,
        title: 'Fondamentaux du cloud',
        accent: const Color(0xFF6C5CE7),
        onInfo: () {},
      ),
      'CodeBlock — copier': const SizedBox(
        width: 360,
        child: CodeBlock(code: 'az login', language: 'bash'),
      ),
      'AnswerChip': AnswerChip(label: 'A', state: QuizOptionState.idle, onTap: () {}),
      'QuizOptionTile': SizedBox(
        width: 360,
        child: QuizOptionTile(label: 'Option A', state: QuizOptionState.idle, onTap: () {}),
      ),
      'PrismButton': PrismButton(label: 'Continuer', onPressed: () {}),
    };

    surfaces.forEach((String name, Widget surface) {
      testWidgets(name, (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        expect(
          await undersizedTargets(tester, surface),
          isEmpty,
          reason: 'Sous $kPrismMinTapTarget pt, le doigt rate la cible. '
              'Envelopper l\'enfant dans PrismTapTarget agrandit la zone '
              'sans changer ce qui est dessiné.',
        );
      });
    });
  });
}
