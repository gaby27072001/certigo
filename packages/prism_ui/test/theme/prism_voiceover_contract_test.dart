import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

/// Contrat VoiceOver des **jauges et des compteurs**.
///
/// Pourquoi ce test existe — la régression qu'il ferme :
///
/// `ReadinessGauge` porte le score de préparation, la métrique North-Star du
/// produit et l'information la plus dense de l'interface. Elle était **muette**
/// en VoiceOver : un `CustomPaint` ne produit aucun nœud sémantique, et les
/// deux `Text` du centre ne se lisaient que comme un nombre nu suivi d'un mot,
/// sans jamais dire que l'un est la valeur de l'autre. `SignalBars`, qui code
/// le niveau de connaissance par un nombre de barres, ne disait rien du tout.
///
/// Le modèle correct existait déjà dans le même paquet — `PrismProgressBar`
/// annonce un `label` et une `value`, `GemCounter`, `XpChip` et `StreakBadge`
/// annoncent un nombre **et son unité**. Ce fichier généralise ce modèle et le
/// rend obligatoire.
///
/// ## Ce qui rend cette garde capable d'échouer
///
/// Vérifier que « le nombre apparaît quelque part » ne garderait rien : le
/// `Text` visible contient déjà le nombre, donc supprimer la sémantique
/// laisserait le test vert. Deux précautions ferment cet angle mort :
///
/// * **Les jauges** doivent porter le nombre dans le champ `value` d'un nœud.
///   Le texte peint ne produit qu'un `label` : retirer le `Semantics` fait
///   disparaître tout `value` et fait rougir.
/// * **Les compteurs** doivent annoncer le nombre **exact** et son unité. Les
///   valeurs choisies ici sont abrégées à l'affichage (`1234` -> `1.2k`), donc
///   retirer le `Semantics` laisse un libellé qui ne contient ni `1234` ni
///   `gemmes` et fait rougir deux fois.
void main() {
  /// Parcourt l'arbre sémantique réellement produit et rend ce que VoiceOver
  /// lirait, nœud par nœud.
  List<SemanticsData> announcements(WidgetTester tester) {
    final SemanticsOwner? owner = tester.binding.pipelineOwner.semanticsOwner;
    final SemanticsNode? root = owner?.rootSemanticsNode;
    final List<SemanticsData> out = <SemanticsData>[];
    void visit(SemanticsNode node) {
      out.add(node.getSemanticsData());
      node.visitChildren((SemanticsNode child) {
        visit(child);
        return true;
      });
    }

    if (root != null) visit(root);
    return out;
  }

  group('une jauge annonce sa valeur', () {
    /// Chaque jauge, la valeur qu'on lui donne, et la chaîne que VoiceOver doit
    /// pouvoir prononcer comme **valeur** et non comme libellé.
    final Map<String, (Widget, String)> gauges = <String, (Widget, String)>{
      'ReadinessGauge': (const ReadinessGauge(score: 72), '72'),
      'PrismProgressBar': (
        const PrismProgressBar(value: 0.4, semanticLabel: 'Objectif du jour'),
        '40',
      ),
      'SignalBars': (const SignalBars(level: 3, color: Color(0xFF3B35F2)), '3'),
    };

    test('la liste des jauges gardées n\'est pas vide', () {
      // Plancher de lecture : une garde qui parcourrait une liste vide passerait
      // au vert sans rien mesurer.
      expect(gauges, isNotEmpty);
    });

    gauges.forEach((String name, (Widget, String) probe) {
      testWidgets('$name porte sa valeur dans le champ `value`', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpPrism(tester, probe.$1);
        await tester.pumpAndSettle();

        final List<SemanticsData> nodes = announcements(tester);
        expect(
          nodes,
          isNotEmpty,
          reason: 'Aucun nœud sémantique : l\'instrument est muet et doit '
              'échouer, pas rendre zéro.',
        );

        final Iterable<String> values =
            nodes.map((SemanticsData d) => d.value).where((String v) => v.isNotEmpty);
        expect(
          values.where((String v) => v.contains(probe.$2)),
          isNotEmpty,
          reason: '$name doit annoncer « ${probe.$2} » comme **valeur**, pas seulement '
              'la peindre. Un `CustomPaint` ne produit aucun nœud sémantique, et un '
              '`Text` ne produit qu\'un libellé.\n'
              'Valeurs annoncées : ${values.toList()}',
        );

        // Un libellé sans valeur ne dit pas ce qui progresse ; une valeur sans
        // libellé ne dit pas de quoi on parle. Les deux sont exigés.
        final Iterable<String> labels =
            nodes.map((SemanticsData d) => d.label).where((String l) => l.isNotEmpty);
        expect(labels, isNotEmpty, reason: '$name doit aussi dire ce qui est mesuré.');

        handle.dispose();
      });
    });
  });

  group('un compteur annonce son nombre et son unité', () {
    /// Les valeurs sont choisies **abrégées à l'affichage** — `1234` se peint
    /// `1.2k` — pour que retirer la sémantique ne puisse pas laisser le test
    /// vert par accident.
    final Map<String, (Widget, String, String)> counters = <String, (Widget, String, String)>{
      'GemCounter': (const GemCounter(gems: 1234), '1234', 'gemmes'),
      'XpChip': (const XpChip(xp: 2345), '2345', 'expérience'),
      'StreakBadge': (const StreakBadge(days: 12), '12', 'jours'),
    };

    test('la liste des compteurs gardés n\'est pas vide', () {
      expect(counters, isNotEmpty);
    });

    counters.forEach((String name, (Widget, String, String) probe) {
      testWidgets('$name annonce « ${probe.$2} » et son unité', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpPrism(tester, probe.$1);
        await tester.pumpAndSettle();

        final List<SemanticsData> nodes = announcements(tester);
        expect(nodes, isNotEmpty, reason: 'Aucun nœud sémantique pour $name.');

        final List<String> spoken = nodes
            .map((SemanticsData d) => '${d.label} ${d.value}'.trim())
            .where((String s) => s.isNotEmpty)
            .toList();

        expect(
          spoken.where((String s) => s.contains(probe.$2) && s.contains(probe.$3)),
          isNotEmpty,
          reason: '$name doit annoncer le nombre exact « ${probe.$2} » **et** son unité '
              '« ${probe.$3} ». Le chiffre peint est abrégé et ne suffit pas : un '
              'lecteur d\'écran qui lirait « 1.2k » ne dirait ni la quantité ni ce '
              'qu\'elle compte.\n'
              'Annoncé : $spoken',
        );

        handle.dispose();
      });
    });
  });

  testWidgets('une jauge déclarée décorative se tait vraiment', (WidgetTester tester) async {
    // L'exception doit être nommée — et elle doit être vérifiable, sinon elle
    // devient la porte de sortie par laquelle le défaut revient.
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpPrism(
      tester,
      const SignalBars(level: 3, color: Color(0xFF3B35F2), semanticLabel: null),
    );
    await tester.pumpAndSettle();

    final List<SemanticsData> nodes = announcements(tester);
    expect(
      nodes.map((SemanticsData d) => '${d.label} ${d.value}').where((String s) => s.contains('3')),
      isEmpty,
      reason: 'Un glyphe explicitement décoratif ne doit rien annoncer du tout.',
    );

    handle.dispose();
  });
}
