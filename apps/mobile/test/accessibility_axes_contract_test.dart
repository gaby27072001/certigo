import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Contrat d'accessibilité **exécuté par la CI**.
///
/// ## Pourquoi ce fichier vit ici et pas dans `packages/prism_ui/test/`
///
/// Le contrat complet — huit apparences, tous les rôles, toutes les surfaces —
/// vit dans `packages/prism_ui/test/theme/`. Il y est plus riche que ce fichier
/// et c'est là qu'il faut le faire évoluer.
///
/// Mais mesuré sur `.github/workflows/` le 2026-09-11 : `packages/prism_ui`
/// n'apparaît qu'à **un seul endroit** de toute la CI (`ci-mobile.yml:326-331`),
/// et ce job lance exactement **un** fichier :
/// `flutter test test/rendering/renderer_golden_test.dart`. Aucun job ne lance
/// la suite `packages/prism_ui/test/`. Témoins de la même recherche :
/// `flutter analyze` -> 5 occurrences, motif inexistant -> 0, donc l'absence est
/// réelle et non un instrument muet.
///
/// Conséquence : **une garde posée dans `packages/prism_ui/test/` ne peut pas
/// faire rougir la CI.** `DESIGN.md` §10 nomme exactement ce cas — « une garde
/// qui ne peut pas échouer est une décoration ».
///
/// Ce fichier est donc le sous-ensemble **décisif** du contrat, placé dans
/// `apps/mobile/test/`, que `ci-mobile.yml:231` exécute par
/// `flutter test --coverage`. Il ne remplace pas la suite de `prism_ui` : il la
/// rend opposable.
///
/// Il garde trois invariants, et chacun correspond à un défaut réellement
/// mesuré sur `main` :
///
/// 1. les huit apparences tiennent leurs planchers de contraste ;
/// 2. sous Reduce Transparency le verre est **opaque**, sans `BackdropFilter` ;
/// 3. les jauges annoncent leur valeur en VoiceOver.
double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Une des huit apparences livrées.
class _Appearance {
  const _Appearance(this.brightness, {this.highContrast = false, this.reduceTransparency = false});

  final Brightness brightness;
  final bool highContrast;
  final bool reduceTransparency;

  PrismColorScheme get scheme => PrismColorScheme.resolve(
        brightness: brightness,
        highContrast: highContrast,
        reduceTransparency: reduceTransparency,
      );

  /// Le pixel réellement affiché par le verre.
  Color get glass => Color.alphaBlend(scheme.glassFill, scheme.background);

  double get textFloor => highContrast ? 7.0 : 4.5;
  double get textOnGlassFloor => highContrast ? 5.5 : 4.5;
  double get glassEdgeFloor => highContrast || reduceTransparency ? 3.0 : 1.60;

  @override
  String toString() {
    final String base = brightness == Brightness.dark ? 'sombre' : 'clair';
    final List<String> axes = <String>[
      if (highContrast) 'contraste+',
      if (reduceTransparency) 'opaque',
    ];
    return axes.isEmpty ? base : '$base ${axes.join('+')}';
  }
}

/// Les huit, énumérées une fois. Quatre traitées en supposant que les quatre
/// autres suivent est l'erreur que ce dépôt a déjà payée : le contraste sombre
/// avait été corrigé pour 108 sites de premier plan **en cassant 6 sites
/// d'aplat**, parce que seul le premier groupe avait été énuméré.
const List<_Appearance> _appearances = <_Appearance>[
  _Appearance(Brightness.light),
  _Appearance(Brightness.light, highContrast: true),
  _Appearance(Brightness.light, reduceTransparency: true),
  _Appearance(Brightness.light, highContrast: true, reduceTransparency: true),
  _Appearance(Brightness.dark),
  _Appearance(Brightness.dark, highContrast: true),
  _Appearance(Brightness.dark, reduceTransparency: true),
  _Appearance(Brightness.dark, highContrast: true, reduceTransparency: true),
];

Map<String, Color> _foregrounds(PrismColorScheme p) => <String, Color>{
      'primary': p.primary,
      'ember': p.ember,
      'xpGold': p.xpGold,
      'success': p.success,
      'warning': p.warning,
      'error': p.error,
      'info': p.info,
      'textPrimary': p.textPrimary,
      'textSecondary': p.textSecondary,
      for (int i = 0; i < 6; i++) 'domaine$i': p.accentOnSurfaceFor(i),
    };

void main() {
  /// Monte [child] sous un thème Prism résolu.
  ///
  /// Le `ThemeData` est passé **à** `MaterialApp` et non enveloppé autour :
  /// un `Theme` posé au-dessus d'un `MaterialApp` est écrasé par le thème de
  /// celui-ci, et la garde mesurerait alors l'apparence par défaut en croyant
  /// mesurer l'apparence demandée.
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
        theme: theme ?? PrismTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  test('les huit combinaisons sont bien huit et toutes distinctes', () {
    // Plancher de lecture : une garde qui parcourrait une liste vide passerait
    // au vert sans rien mesurer. §7 de `docs/GOVERNANCE.md` — un instrument qui
    // n'a rien lu doit échouer, pas rendre zéro.
    expect(_appearances, hasLength(8));
    expect(_appearances.map((_Appearance a) => a.toString()).toSet(), hasLength(8));
    expect(_foregrounds(PrismColorScheme.light), isNotEmpty);
  });

  group('les huit apparences tiennent leurs planchers', () {
    for (final _Appearance a in _appearances) {
      test('$a', () {
        final PrismColorScheme p = a.scheme;
        _foregrounds(p).forEach((String name, Color c) {
          expect(
            _contrast(c, p.surface),
            greaterThanOrEqualTo(a.textFloor),
            reason: '$name sur la carte en $a',
          );
          expect(
            _contrast(c, p.background),
            greaterThanOrEqualTo(a.textFloor),
            reason: '$name sur la page en $a',
          );
          expect(
            _contrast(c, a.glass),
            greaterThanOrEqualTo(a.textOnGlassFloor),
            reason: '$name sur le verre en $a',
          );
        });

        // Le verre reste un plan : le rendre opaque ne doit pas le faire
        // fusionner avec le fond qu'il survole.
        expect(
          _contrast(a.glass, p.background),
          greaterThanOrEqualTo(1.12),
          reason: 'le verre doit rester un plan en $a',
        );

        // L'arête reprend la charge que le flou portait.
        final Color stroke = Color.alphaBlend(p.glassStroke, a.glass);
        expect(
          _contrast(stroke, a.glass),
          greaterThanOrEqualTo(a.glassEdgeFloor),
          reason: 'le trait du verre en $a',
        );
      });
    }
  });

  group('Reduce Transparency supprime vraiment la translucidité', () {
    for (final Brightness b in Brightness.values) {
      final String name = b == Brightness.dark ? 'sombre' : 'clair';

      testWidgets('aucun BackdropFilter ne subsiste ($name)', (WidgetTester tester) async {
        // `glass_surface.dart` est la **seule** source de flou du dépôt, et elle
        // porte les deux barres de l'application : la barre d'onglets
        // (`app_shell.dart`) et l'entête partagé par 8 écrans
        // (`screen_header.dart`).
        await tester.pumpWidget(
          host(
            const GlassSurface(child: Text('Opaque')),
            theme: PrismTheme.resolve(brightness: b, reduceTransparency: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Opaque'), findsOneWidget);
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason: 'Reduce Transparency ne demande pas moins de flou, il demande '
              'qu\'il n\'y en ait plus.',
        );
      });

      testWidgets('le flou est bien là quand le réglage est absent ($name)',
          (WidgetTester tester) async {
        // Témoin : sans ce contrôle, l'assertion ci-dessus passerait au vert si
        // `GlassSurface` cessait purement et simplement de flouter. Une absence
        // n'informe que si l'instrument peut rendre une présence.
        await tester.pumpWidget(
          host(
            const GlassSurface(child: Text('Verre')),
            theme: PrismTheme.resolve(brightness: b),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);
      });

      test('le fond du verre est opaque ($name)', () {
        final PrismColorScheme p =
            PrismColorScheme.resolve(brightness: b, reduceTransparency: true);
        expect(p.glassFill.a, 1.0, reason: 'le fond du verre doit être opaque en $name');
      });

      test('le réglage ne déborde pas sur les bordures de cartes ($name)', () {
        final PrismColorScheme base = PrismColorScheme.resolve(brightness: b);
        final PrismColorScheme rt =
            PrismColorScheme.resolve(brightness: b, reduceTransparency: true);
        expect(rt.border, base.border);
        expect(rt.borderStrong, base.borderStrong);
        expect(rt.textPrimary, base.textPrimary);
      });
    }
  });

  group('les jauges annoncent leur valeur en VoiceOver', () {
    /// Chaque jauge et la chaîne que VoiceOver doit prononcer comme **valeur**.
    ///
    /// Exiger le champ `value` — et non « le nombre apparaît quelque part » —
    /// est ce qui rend cette garde capable d'échouer : le texte peint contient
    /// déjà le nombre, donc une assertion sur le texte resterait verte si toute
    /// la sémantique disparaissait.
    final Map<String, (Widget, String)> gauges = <String, (Widget, String)>{
      'ReadinessGauge': (const ReadinessGauge(score: 72), '72'),
      'PrismProgressBar': (
        const PrismProgressBar(value: 0.4, semanticLabel: 'Objectif du jour'),
        '40',
      ),
      'SignalBars': (const SignalBars(level: 3, color: Color(0xFF3B35F2)), '3'),
    };

    test('la liste des jauges gardées n\'est pas vide', () {
      expect(gauges, isNotEmpty);
    });

    gauges.forEach((String name, (Widget, String) probe) {
      testWidgets('$name porte sa valeur dans le champ `value`', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(host(probe.$1));
        await tester.pumpAndSettle();

        final List<String> values = <String>[];
        void visit(SemanticsNode node) {
          final String v = node.getSemanticsData().value;
          if (v.isNotEmpty) values.add(v);
          node.visitChildren((SemanticsNode child) {
            visit(child);
            return true;
          });
        }

        final SemanticsNode? root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
        expect(root, isNotNull, reason: 'aucun arbre sémantique : instrument muet');
        visit(root!);

        expect(
          values.where((String v) => v.contains(probe.$2)),
          isNotEmpty,
          reason: '$name doit annoncer « ${probe.$2} » comme **valeur**, pas seulement '
              'la peindre. Un `CustomPaint` ne produit aucun nœud sémantique.\n'
              'Valeurs annoncées : $values',
        );

        handle.dispose();
      });
    });
  });
}
