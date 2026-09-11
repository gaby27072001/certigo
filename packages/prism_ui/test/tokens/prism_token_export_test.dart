import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Contrat de la **source neutre de tokens** — l'artefact que consommeront les
/// applications natives.
///
/// ## La dérive que ce fichier ferme
///
/// Le produit part en natif, iOS d'abord, Android ensuite. Entre les deux, la
/// source de vérité continue de vivre. Un fichier partagé que personne ne
/// vérifie n'empêche aucune dérive : c'est le motif d'échec dominant de ce
/// dépôt — *construire un mécanisme complet et ne pas le brancher*.
///
/// Trois gardes, et elles ne gardent pas la même chose :
///
/// 1. **La fraîcheur.** Le JSON committé doit être exactement ce que le Dart
///    produit aujourd'hui. Modifier une couleur sans régénérer fait rougir ici.
/// 2. **La complétude des primitives.** Les noms sont relus dans le *source*
///    de `prism_colors.dart` : ajouter un token Dart sans l'exporter fait
///    rougir. C'est la dérive par **omission**, et c'est la plus discrète — un
///    document qui reste valide en devenant incomplet ne signale rien.
/// 3. **La complétude des rôles sémantiques.** Même mécanisme sur les champs de
///    `PrismColorScheme`. C'est la garde qui compte le plus : `prism_color_scheme.dart`
///    dit lui-même « *This is the layer UI code should depend on — never the raw
///    PrismColors* ». Un export qui perdrait un rôle forcerait Swift à le
///    re-dériver, ce qui est exactement la faute qu'a documentée
///    `prism_contrast_contract_test.dart` (six accents sur sept tombés entre
///    2.6:1 et 3.1:1 en sombre, parce que les tests regardaient les primitives
///    et jamais les rôles résolus).
///
/// ## Régénérer
///
/// ```powershell
/// $env:PRISM_TOKENS_WRITE = '1'
/// flutter test test/tokens/prism_token_export_test.dart
/// Remove-Item Env:\PRISM_TOKENS_WRITE
/// ```
///
/// Même geste que `--update-goldens`, et pour la même raison : l'artefact est
/// une empreinte, pas une saisie.
void main() {
  /// Les tests s'exécutent avec le répertoire courant à la racine du paquet.
  const String artifactPath = 'schemas/tokens/v1/prism-tokens.json';
  const String colorsSourcePath = 'lib/src/tokens/prism_colors.dart';
  const String schemeSourcePath = 'lib/src/theme/prism_color_scheme.dart';

  /// Sérialisation canonique : un seul encodage possible, sinon la comparaison
  /// octet à octet signalerait des différences de mise en forme.
  String encode(Map<String, Object?> document) =>
      '${const JsonEncoder.withIndent('  ').convert(document)}\n';

  group('source neutre de tokens', () {
    test('le fichier committé est exactement ce que le Dart produit', () {
      final String expected = encode(PrismTokenExport.build());
      final File artifact = File(artifactPath);

      if (Platform.environment['PRISM_TOKENS_WRITE'] == '1') {
        artifact.parent.createSync(recursive: true);
        artifact.writeAsStringSync(expected);
        return;
      }

      expect(
        artifact.existsSync(),
        isTrue,
        reason: '$artifactPath est absent. Régénérer avec PRISM_TOKENS_WRITE=1.',
      );
      expect(
        artifact.readAsStringSync().replaceAll('\r\n', '\n'),
        expected,
        reason: 'Les tokens Dart ont changé sans que $artifactPath soit régénéré.\n'
            'Le Dart reste la source ; ce fichier en dérive.\n'
            'Correctif : PRISM_TOKENS_WRITE=1 flutter test '
            'test/tokens/prism_token_export_test.dart, puis committer le résultat.',
      );
    });

    test('aucune primitive de PrismColors n\'échappe à l\'export', () {
      final Set<String> declared = _declaredColorNames(File(colorsSourcePath).readAsStringSync());
      final Map<String, Object?> color = PrismTokenExport.build()['color']! as Map<String, Object?>;
      final Set<String> exported = <String>{
        ...(color['primitive']! as Map<String, Object?>).keys,
        ...(color['primitiveSets']! as Map<String, Object?>).keys,
      };

      expect(
        declared,
        isNotEmpty,
        reason: 'La lecture de $colorsSourcePath n\'a trouvé aucun token : '
            'l\'instrument est muet et doit échouer, pas rendre zéro.',
      );
      expect(
        declared.difference(exported),
        isEmpty,
        reason: 'Ces primitives sont déclarées dans $colorsSourcePath mais absentes du '
            'format neutre : une app native ne pourra pas les lire.\n'
            'Correctif : les ajouter dans PrismTokenExport, puis régénérer.',
      );
    });

    test('aucun rôle sémantique de PrismColorScheme n\'échappe à l\'export', () {
      final Set<String> declared = _declaredFieldNames(File(schemeSourcePath).readAsStringSync());
      final Map<String, Object?> scheme = (PrismTokenExport.build()['color']!
          as Map<String, Object?>)['scheme']! as Map<String, Object?>;

      expect(
        declared,
        isNotEmpty,
        reason: 'La lecture de $schemeSourcePath n\'a trouvé aucun rôle : '
            'l\'instrument est muet et doit échouer, pas rendre zéro.',
      );

      for (final String appearance in <String>['light', 'dark']) {
        final Map<String, Object?> resolved = scheme[appearance]! as Map<String, Object?>;
        final Set<String> exported = <String>{
          ...(resolved['roles']! as Map<String, Object?>).keys,
          ...(resolved['roleSets']! as Map<String, Object?>).keys,
        };
        expect(
          declared.difference(exported),
          isEmpty,
          reason: 'Ces rôles sont déclarés dans $schemeSourcePath mais absents de '
              'l\'apparence "$appearance" du format neutre.\n'
              'Un rôle manquant oblige la plateforme native à le re-dériver, '
              'ce qui est précisément la faute documentée par '
              'prism_contrast_contract_test.dart.\n'
              'Correctif : les ajouter dans PrismTokenExport, puis régénérer.',
        );
      }
    });

    test('les deux apparences publient des rôles réellement distincts', () {
      // Une teinte interactive doit changer d'apparence — l'assertion inverse
      // encodait le bug corrigé par la refonte. Si l'export aplatissait les
      // deux apparences, le natif hériterait d'un mode sombre illisible.
      final Map<String, Object?> scheme = (PrismTokenExport.build()['color']!
          as Map<String, Object?>)['scheme']! as Map<String, Object?>;
      Map<String, Object?> roles(String appearance) =>
          (scheme[appearance]! as Map<String, Object?>)['roles']! as Map<String, Object?>;

      expect(roles('light')['primary'], isNot(roles('dark')['primary']));
      expect(roles('light')['error'], isNot(roles('dark')['error']));
      expect(roles('light')['primaryFill'], roles('dark')['primaryFill']);
    });

    test('toute couleur exportée est un #AARRGGBB littéral', () {
      final RegExp form = RegExp(r'^#[0-9A-F]{8}$');
      final Map<String, Object?> color = PrismTokenExport.build()['color']! as Map<String, Object?>;
      final List<String> values = <String>[
        ...(color['primitive']! as Map<String, Object?>).values.cast<String>(),
        for (final Object? set in (color['primitiveSets']! as Map<String, Object?>).values)
          ...(set! as List<Object?>).cast<String>(),
      ];

      expect(values, isNotEmpty);
      for (final String value in values) {
        expect(value, matches(form), reason: '"$value" n\'est pas au format #AARRGGBB.');
      }
    });

    test('le document se relit tel quel — il est vraiment portable', () {
      final Map<String, Object?> document = PrismTokenExport.build();
      final Object? roundTrip = jsonDecode(jsonEncode(document));
      expect(roundTrip, isA<Map<String, Object?>>());
      expect(
        (roundTrip! as Map<String, Object?>)['tokenSchemaVersion'],
        PrismTokenExport.schemaVersion,
      );
    });
  });
}

/// Relit les noms de tokens couleur déclarés dans le *source* Dart.
///
/// Lire le fichier plutôt que de recopier une liste est ce qui rend la garde
/// capable de détecter un ajout : une liste écrite à la main dériverait
/// exactement comme le JSON qu'elle prétend garder.
Set<String> _declaredColorNames(String source) {
  final RegExp single = RegExp(r'static const Color (\w+)\s*=');
  final RegExp list = RegExp(r'static const List<Color> (\w+)\s*=');
  return <String>{
    for (final RegExpMatch match in single.allMatches(source)) match.group(1)!,
    for (final RegExpMatch match in list.allMatches(source)) match.group(1)!,
  };
}

/// Relit les champs couleur déclarés par [PrismColorScheme].
Set<String> _declaredFieldNames(String source) {
  final RegExp single = RegExp(r'^  final Color (\w+);', multiLine: true);
  final RegExp list = RegExp(r'^  final List<Color> (\w+);', multiLine: true);
  return <String>{
    for (final RegExpMatch match in single.allMatches(source)) match.group(1)!,
    for (final RegExpMatch match in list.allMatches(source)) match.group(1)!,
  };
}
