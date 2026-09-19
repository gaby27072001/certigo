import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Garde des **chiffres tabulaires** : un compteur ne doit pas faire danser la
/// mise en page quand son nombre change.
///
/// Le piège que ce fichier ferme, et pourquoi il mesure des pixels plutôt que
/// de lire un drapeau :
///
/// 1. `FontFeature.tabularFigures()` est une *demande*, pas une garantie. Si la
///    famille n'embarque pas la fonctionnalité OpenType `tnum`, Flutter
///    l'ignore **en silence** : le style porte la fonctionnalité, le rendu ne
///    change pas, et un test qui se contenterait de vérifier
///    `style.fontFeatures` serait vert sur un correctif sans aucun effet.
///    Archivo la fournit (`GSUB`, dix substitutions `zero` → `zero.tf`) — ce
///    fichier est ce qui le prouve, et ce qui rougira le jour où la famille de
///    marque sera remplacée par une fonte qui ne la fournit pas.
///
/// 2. Les goldens ne peuvent pas jouer ce rôle. `test/rendering/` rend en
///    police **Ahem**, dont chaque glyphe est un rectangle de chasse uniforme :
///    un golden ne distinguerait structurellement pas des chiffres tabulaires
///    de chiffres proportionnels. La vraie fonte est donc chargée ici.
///
/// 3. Comparer « 111 » à « 000 » ne suffit pas. Archivo dessine ses chiffres
///    presque isométriques autour de la graisse 600 — la bande où vivent
///    justement les libellés de compteur — et les laisse diverger aux deux
///    extrémités de l'axe. Dans `labelLarge`, « 111 » et « 000 » ne diffèrent
///    que de **0,045 px** tandis que l'écart réel entre le chiffre le plus
///    large et le plus étroit atteint **1,17 px**. La garde mesure donc les
///    **dix** chiffres.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadBrandFont);

  const Color ink = Color(0xFF101418);
  const Color muted = Color(0xFF6B7280);

  TextTheme theme() => PrismTypography.build(ink, muted);

  group('la forme survit à Bold Text', () {
    // Ajouté après la fusion de #495, qui introduit `boldText` : sous Bold
    // Text, chaque créneau parcourt 60 % de ce qui le sépare de 900 — le corps
    // passe de 400 à 700, `labelLarge` de 600 à 780, Display de 800 à 860.
    //
    // Ce n'est pas un détail pour cette garde : tout son résultat est que
    // l'écart des chiffres d'Archivo **dépend de la graisse** et n'est pas
    // monotone. Un axe déplacé est donc un jeu de chasses différent, et une
    // garde mesurée uniquement à la graisse nominale ne dirait rien du
    // chemin accessible — celui des utilisateurs qui en ont le plus besoin.
    final TextTheme bold = PrismTypography.build(ink, muted, boldText: true);

    test('Bold Text déplace bien l\'axe de graisse', () {
      // Contrôle : sans lui, les deux tests suivants pourraient mesurer le
      // thème nominal en croyant mesurer le thème gras.
      double wght(TextStyle s) =>
          s.fontVariations!.firstWhere((FontVariation v) => v.axis == 'wght').value;
      expect(wght(bold.bodyLarge!), greaterThan(wght(theme().bodyLarge!)));
      expect(wght(bold.displayMedium!), greaterThan(wght(theme().displayMedium!)));
    });

    test('les chiffres proportionnels dansent encore sous Bold Text', () {
      expect(_digitSpread(bold.displayMedium!), greaterThan(0.5));
    });

    test('tabular égalise les dix chiffres sous Bold Text aussi', () {
      for (final TextStyle style in <TextStyle>[
        PrismTypography.tabular(bold.displayMedium)!,
        PrismTypography.tabular(bold.titleLarge)!,
        PrismTypography.tabular(bold.labelLarge)!,
        PrismTypography.tabular(bold.labelMedium)!,
      ]) {
        expect(_digitSpread(style), 0);
      }
    });
  });

  group('Archivo fournit réellement les chiffres tabulaires', () {
    // Ce test est le contrôle : il affirme que le défaut à corriger EXISTE.
    // Si la famille de marque devient un jour une fonte aux chiffres déjà
    // isométriques, il rougira pour dire que ce lot n'a plus d'objet — et non
    // pour dire qu'il est cassé.
    test('les chiffres proportionnels font bien danser la mise en page', () {
      final TextTheme t = theme();
      for (final MapEntry<String, TextStyle> slot in <String, TextStyle>{
        'displayMedium': t.displayMedium!,
        'bodyLarge': t.bodyLarge!,
        'labelLarge': t.labelLarge!,
      }.entries) {
        expect(
          _digitSpread(slot.value),
          greaterThan(0.5),
          reason: 'Les chiffres proportionnels de ${slot.key} sont déjà isométriques : '
              'les chiffres tabulaires n\'achètent plus rien et ce lot est sans objet.',
        );
      }
    });

    test('la fonctionnalité tnum est appliquée, pas seulement demandée', () {
      // La différence entre « le style porte la fonctionnalité » et « le rendu
      // change ». C'est le seul test qui distingue un correctif d'un placebo.
      final TextStyle proportional = theme().displayMedium!;
      final TextStyle tabular = PrismTypography.tabular(proportional)!;
      expect(
        _width('000', tabular),
        isNot(closeTo(_width('000', proportional), 0.001)),
        reason: 'Le rendu est identique avec et sans tabularFigures : Flutter a ignoré '
            'la fonctionnalité. La famille de marque n\'embarque probablement pas `tnum`.',
      );
    });
  });

  group('PrismTypography.tabular égalise les dix chiffres', () {
    // Les quinze créneaux, pas seulement ceux qu'un compteur utilise
    // aujourd'hui : le modificateur est public et doit tenir partout.
    final Map<String, TextStyle Function(TextTheme)> slots =
        <String, TextStyle Function(TextTheme)>{
      'displayLarge': (TextTheme t) => t.displayLarge!,
      'displayMedium': (TextTheme t) => t.displayMedium!,
      'displaySmall': (TextTheme t) => t.displaySmall!,
      'headlineLarge': (TextTheme t) => t.headlineLarge!,
      'headlineMedium': (TextTheme t) => t.headlineMedium!,
      'headlineSmall': (TextTheme t) => t.headlineSmall!,
      'titleLarge': (TextTheme t) => t.titleLarge!,
      'titleMedium': (TextTheme t) => t.titleMedium!,
      'titleSmall': (TextTheme t) => t.titleSmall!,
      'bodyLarge': (TextTheme t) => t.bodyLarge!,
      'bodyMedium': (TextTheme t) => t.bodyMedium!,
      'bodySmall': (TextTheme t) => t.bodySmall!,
      'labelLarge': (TextTheme t) => t.labelLarge!,
      'labelMedium': (TextTheme t) => t.labelMedium!,
      'labelSmall': (TextTheme t) => t.labelSmall!,
    };

    for (final MapEntry<String, TextStyle Function(TextTheme)> slot in slots.entries) {
      test('${slot.key} rend les dix chiffres à la même chasse', () {
        final TextStyle style = PrismTypography.tabular(slot.value(theme()))!;
        expect(
          _digitSpread(style),
          0,
          reason: '${slot.key} garde des chasses inégales une fois passé par '
              'PrismTypography.tabular : le nombre bougera à chaque changement de chiffre.',
        );
      });
    }

    test('« 111 » et « 000 » ont exactement la même largeur', () {
      final TextTheme t = theme();
      for (final TextStyle style in <TextStyle>[
        PrismTypography.tabular(t.displayMedium)!,
        PrismTypography.tabular(t.titleLarge)!,
        PrismTypography.tabular(t.labelLarge)!,
        PrismTypography.tabular(t.labelMedium)!,
      ]) {
        expect(_width('111', style), _width('000', style));
      }
    });
  });

  group('le modificateur se comporte comme un modificateur', () {
    test('il est idempotent', () {
      final TextStyle once = PrismTypography.tabular(theme().labelLarge)!;
      final TextStyle twice = PrismTypography.tabular(once)!;
      expect(twice.fontFeatures, hasLength(1));
      expect(_width('000', twice), _width('000', once));
    });

    test('il préserve les fonctionnalités OpenType déjà posées', () {
      const FontFeature slashedZero = FontFeature.slashedZero();
      final TextStyle base = theme().labelLarge!.copyWith(
        fontFeatures: const <FontFeature>[slashedZero],
      );
      expect(
        PrismTypography.tabular(base)!.fontFeatures,
        containsAll(<FontFeature>[slashedZero, const FontFeature.tabularFigures()]),
      );
    });

    test('il ne consomme aucun créneau de TextTheme', () {
      // Règle n°4 de DESIGN.md : les quinze créneaux appartiennent à la marque.
      // Un compteur ne doit donc pas en réquisitionner un ; il compose.
      final TextStyle style = PrismTypography.tabular(theme().labelLarge)!;
      expect(style.fontSize, theme().labelLarge!.fontSize);
      expect(style.fontVariations, theme().labelLarge!.fontVariations);
      expect(style.color, theme().labelLarge!.color);
    });

    test('il laisse passer null comme les créneaux nullables du thème', () {
      expect(PrismTypography.tabular(null), isNull);
    });
  });

  group('les compteurs du produit adoptent la forme', () {
    // Le pendant « site d'appel » de la garde, sur le modèle de
    // `prism_fill_role_guard_test.dart` : le jeton peut être correct pendant
    // qu'un composant oublie de s'en servir. On ne lit pas le drapeau — on
    // remesure la chasse du style réellement rendu par le widget.
    for (final MapEntry<String, Widget> counter in <String, Widget>{
      'StreakBadge': const StreakBadge(days: 128),
      'XpChip': const XpChip(xp: 1408, delta: 30),
      'GemCounter': const GemCounter(gems: 470, delta: 5),
      'StatPill.streak': StatPill.streak(128),
      'StatPill.xp': StatPill.xp(1408),
      'ReadinessGauge': const ReadinessGauge(score: 78),
    }.entries) {
      testWidgets('${counter.key} rend ses chiffres à chasse fixe', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: PrismTheme.light(),
            home: Scaffold(body: Center(child: counter.value)),
          ),
        );
        await tester.pumpAndSettle();

        final Iterable<Text> numeric = tester
            .widgetList<Text>(find.byType(Text))
            .where((Text t) => (t.data ?? '').contains(RegExp(r'\d')));

        expect(numeric, isNotEmpty, reason: '${counter.key} ne rend aucun chiffre.');
        for (final Text text in numeric) {
          expect(
            _digitSpread(text.style!),
            0,
            reason: '${counter.key} rend « ${text.data} » en chiffres proportionnels. '
                'Envelopper son style dans PrismTypography.tabular(...).',
          );
        }
      });
    }
  });
}

/// Charge la vraie Archivo. Sans cela `flutter test` rend tout en Ahem, dont
/// les glyphes ont déjà tous la même chasse — la mesure serait uniformément
/// nulle et la garde ne pourrait jamais rougir.
Future<void> _loadBrandFont() async {
  final Uint8List bytes = await File('assets/fonts/Archivo-Variable.ttf').readAsBytes();
  final ByteData data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
  // Le nom résolu porte le préfixe de paquet ; l'autre sert aux styles écrits
  // sans `package:`.
  for (final String family in <String>['Archivo', 'packages/prism_ui/Archivo']) {
    final FontLoader loader = FontLoader(family)..addFont(Future<ByteData>.value(data));
    await loader.load();
  }
}

/// Largeur rendue de [text], en pixels logiques.
///
/// Mesurée via `computeLineMetrics()` et non `TextPainter.width` : ce dernier
/// arrondit à l'entier supérieur, ce qui masquerait précisément les écarts
/// sous-pixel que cette garde doit voir.
double _width(String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final double width = painter.computeLineMetrics().single.width;
  painter.dispose();
  return width;
}

/// Écart de chasse entre le chiffre le plus large et le plus étroit, mesuré sur
/// des suites de huit pour porter l'écart au-dessus du bruit d'arrondi.
///
/// Vaut exactement 0 si et seulement si les dix chiffres sont isométriques.
double _digitSpread(TextStyle style) {
  final List<double> widths = List<double>.generate(
    10,
    (int digit) => _width('$digit' * 8, style),
  );
  return widths.reduce((double a, double b) => a > b ? a : b) -
      widths.reduce((double a, double b) => a < b ? a : b);
}
