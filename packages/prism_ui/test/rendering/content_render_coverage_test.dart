import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Couverture de rendu : **ce que le contenu peut dire contre ce que l'app sait
/// peindre.**
///
/// ## La mesure qui a motivé ce fichier
///
/// Le dépôt possède déjà deux briques portables — les tokens de design et le
/// schéma de contenu v2 — et un test de cohérence relie le catalogue Dart à
/// l'artefact AJV. Rien, en revanche, ne reliait ce catalogue au **registre de
/// rendu réellement câblé**. Mesuré sur cet arbre :
///
/// * le catalogue canonique v2 déclare **13 types** ;
/// * `standardRendererRegistry()` — l'unique registre de production, référencé
///   par `apps/mobile/lib/features/lesson/application/lesson_renderer.dart` —
///   en enregistre **6** ;
/// * l'intersection est de **2** (`concept`, `example`).
///
/// La divergence va donc dans les **deux sens**, et chacun a une conséquence
/// visible :
///
/// * **11 types canoniques n'ont aucun renderer.** Un contenu parfaitement
///   valide au regard de `block.schema.json` se peint en
///   [PrismBlockFallback] `unknownType`. Le contenu passe la validation et
///   n'apparaît pas.
/// * **4 types peints ne sont pas canoniques** (`hook`, `code`, `recap`,
///   `callout`). Ils s'affichent correctement mais [ContentBlockValidator] les
///   rejette en `unknownType`. La validation refuse ce que l'app sait faire.
///
/// ## Pourquoi une garde à cliquet, et non une correction
///
/// Câbler les 11 types manquants est un travail de rendu, hors du périmètre qui
/// a produit ce fichier, et le faire à l'aveugle casserait les goldens. Ce test
/// ne corrige donc rien : il **épingle l'écart** pour qu'il devienne un fait
/// visible et non plus une découverte.
///
/// L'effet recherché est un cliquet. Ajouter un type canonique sans renderer
/// fait rougir ; ajouter un renderer fait rougir aussi, et l'auteur met à jour
/// l'épingle — en réduisant l'écart. Dans les deux cas la divergence devient un
/// acte délibéré, jamais un silence.
///
/// C'est ce qui manquait : les deux briques portables décrivent chacune leur
/// moitié du contrat de contenu, et **rien ne vérifiait qu'elles parlent du
/// même objet**.
void main() {
  /// Les types que le catalogue canonique v2 déclare.
  final Set<String> canonical = <String>{
    for (final CanonicalBlockType type in CanonicalBlockType.values) type.wire,
  };

  /// Les types que le registre de production sait réellement peindre.
  final Set<String> rendered = standardRendererRegistry().registeredTypes.toSet();

  group('couverture de rendu du contenu canonique', () {
    test('les deux instruments répondent — aucun ne rend zéro en silence', () {
      // Un ensemble vide ferait passer toutes les différences ci-dessous. La
      // garde doit échouer si elle devient muette, pas rendre « aucun écart ».
      expect(canonical, isNotEmpty, reason: 'Le catalogue canonique est vide.');
      expect(rendered, isNotEmpty, reason: 'Le registre de rendu est vide.');
    });

    test('un contenu canonique valide peut rester invisible — écart épinglé', () {
      // Ces types passent `block.schema.json` et se peignent en fallback
      // `unknownType`. Câbler un renderer ? Retirer la ligne correspondante.
      expect(
        canonical.difference(rendered),
        <String>{
          'hero',
          'diagram',
          'quiz.multipleChoice',
          'quiz.trueFalse',
          'quiz.matching',
          'scenario',
          'caseStudy',
          'labStep',
          'aiTutorPrompt',
          'examQuestion',
          'summary',
        },
        reason: 'La liste des types canoniques sans renderer a changé.\n'
            'Un type ajouté ici se valide mais ne s\'affiche pas : il se peint '
            'en PrismBlockFallback(unknownType).\n'
            'Correctif : câbler le renderer dans standard_renderers.dart, ou '
            'mettre à jour cette épingle en connaissance de cause.',
      );
    });

    test('un type peint peut être refusé par la validation — écart épinglé', () {
      // Ces types s'affichent mais ContentBlockValidator les rejette. Un
      // pipeline d'ingestion qui validerait le contenu supprimerait des blocs
      // que l'application sait pourtant peindre.
      expect(
        rendered.difference(canonical),
        <String>{'hook', 'code', 'recap', 'callout'},
        reason: 'La liste des types peints hors catalogue canonique a changé.\n'
            'Un type peint mais non canonique est rejeté par '
            'ContentBlockValidator en `unknownType`.\n'
            'Correctif : l\'ajouter à CanonicalBlockType et à '
            'schemas/content/v2/block.schema.json, ou mettre à jour cette '
            'épingle en connaissance de cause.',
      );
    });

    test('le socle commun aux deux contrats est nommé', () {
      // La seule zone où contenu et rendu s'accordent aujourd'hui. Elle doit
      // grandir ; elle ne doit jamais rétrécir sans que quelqu'un le dise.
      expect(
        canonical.intersection(rendered),
        <String>{'concept', 'example'},
        reason: 'Le socle commun contenu/rendu a changé.\n'
            'S\'il a grandi : très bien, mettre à jour cette épingle.\n'
            'S\'il a rétréci : un type de contenu vient de cesser d\'être peint.',
      );
    });

    test('chaque type peint en commun sait décrire son propre payload', () {
      // Un type dans le socle commun doit avoir une définition de payload :
      // sans elle, le contrat portable ne dit pas à une plateforme native quels
      // champs lire, et le renderer Dart reste la seule spécification.
      final ContentSchemaRegistry registry = ContentSchemaRegistry.canonicalV2();
      for (final String wire in canonical.intersection(rendered)) {
        final CanonicalBlockType? type = CanonicalBlockType.fromWire(wire);
        expect(type, isNotNull, reason: '"$wire" n\'est pas résoluble.');
        expect(
          registry.schemaFor(type!)?.requiredFieldNames,
          isNotEmpty,
          reason: '"$wire" est peint mais ne déclare aucun champ requis : '
              'une plateforme native n\'a rien à lire.',
        );
      }
    });
  });
}
