import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Miroir **exécuté en CI** du contrat de la source neutre de tokens.
///
/// ## Pourquoi ce test vit ici et non dans `prism_ui`
///
/// La garde de référence est
/// `packages/prism_ui/test/tokens/prism_token_export_test.dart`, et elle est
/// plus complète que ce fichier. Mais elle ne s'exécute nulle part.
///
/// Mesuré : `prism_ui` n'apparaît dans `.github/workflows/` qu'à un seul
/// endroit, et ce pas ne lance que `test/rendering/renderer_golden_test.dart`.
/// Les 274 autres tests du paquet — y compris les trois gardes sémantiques de
/// `test/theme/` et la garde de dérive des tokens — ne tournent qu'en local.
/// Une garde qui ne s'exécute pas n'est pas une garde.
///
/// Le pas CI correspondant a été écrit puis retiré : le validateur de workflows
/// (`.github/scripts/account-deletion-cosmos-policy.mjs`) compare **chaque**
/// workflow du manifeste au candidat et lit le manifeste de la *base*, si bien
/// que le remède qu'il affiche lui-même — faire atterrir le manifeste régénéré
/// sur `main` avant le changement de workflow — ouvre une fenêtre pendant
/// laquelle toute PR ouverte échoue au gate. Le rayon de souffle dépassait le
/// bénéfice.
///
/// `apps/mobile/test/` est, lui, exécuté par `flutter test --coverage` dans le
/// job « Flutter app + UI packages ». L'application dépend déjà de `prism_ui`
/// et le paquet est atteignable par chemin relatif. Poser le miroir ici est
/// donc ce qui fait réellement mordre la garde aujourd'hui, sans toucher à un
/// workflow.
///
/// À supprimer le jour où le pas « Gardes de contrat » entre dans
/// `ci-mobile.yml` — mais pas avant : ce serait rendre la dérive silencieuse à
/// nouveau.
void main() {
  // `flutter test` s'exécute avec le répertoire courant à `apps/mobile`.
  const String packageRoot = '../../packages/prism_ui';
  const String artifactPath = '$packageRoot/schemas/tokens/v1/prism-tokens.json';
  const String colorsSourcePath = '$packageRoot/lib/src/tokens/prism_colors.dart';
  const String schemeSourcePath = '$packageRoot/lib/src/theme/prism_color_scheme.dart';

  String encode(Map<String, Object?> document) =>
      '${const JsonEncoder.withIndent('  ').convert(document)}\n';

  Set<String> namesMatching(String source, List<RegExp> patterns) => <String>{
        for (final RegExp pattern in patterns)
          for (final RegExpMatch match in pattern.allMatches(source)) match.group(1)!,
      };

  group('source neutre des tokens Prism (miroir exécuté en CI)', () {
    test('le paquet prism_ui est atteignable depuis ce test', () {
      // Si le chemin relatif casse, toutes les lectures ci-dessous rendraient
      // du vide et les assertions passeraient sur rien. L'instrument doit
      // échouer quand il devient muet, pas rendre zéro.
      expect(
        File(colorsSourcePath).existsSync(),
        isTrue,
        reason: '$colorsSourcePath est introuvable : le chemin relatif vers '
            'prism_ui a changé et ce miroir ne mesure plus rien.',
      );
      expect(File(schemeSourcePath).existsSync(), isTrue);
    });

    test('le fichier committé est exactement ce que le Dart produit', () {
      final File artifact = File(artifactPath);
      expect(
        artifact.existsSync(),
        isTrue,
        reason: '$artifactPath est absent.',
      );
      expect(
        artifact.readAsStringSync().replaceAll('\r\n', '\n'),
        encode(PrismTokenExport.build()),
        reason: 'Les tokens Dart ont changé sans que la source neutre soit '
            'régénérée.\n'
            'Correctif, depuis packages/prism_ui :\n'
            '  PRISM_TOKENS_WRITE=1 flutter test '
            'test/tokens/prism_token_export_test.dart',
      );
    });

    test('aucune primitive de PrismColors n\'échappe à l\'export', () {
      final Set<String> declared = namesMatching(
        File(colorsSourcePath).readAsStringSync(),
        <RegExp>[
          RegExp(r'static const Color (\w+)\s*='),
          RegExp(r'static const List<Color> (\w+)\s*='),
        ],
      );
      final Map<String, Object?> color = PrismTokenExport.build()['color']! as Map<String, Object?>;
      final Set<String> exported = <String>{
        ...(color['primitive']! as Map<String, Object?>).keys,
        ...(color['primitiveSets']! as Map<String, Object?>).keys,
      };

      expect(declared, isNotEmpty);
      expect(
        declared.difference(exported),
        isEmpty,
        reason: 'Ces primitives sont déclarées dans prism_colors.dart mais '
            'absentes de la source neutre : une app native ne pourra pas les '
            'lire.',
      );
    });

    test('aucun rôle sémantique de PrismColorScheme n\'échappe à l\'export', () {
      final Set<String> declared = namesMatching(
        File(schemeSourcePath).readAsStringSync(),
        <RegExp>[
          RegExp(r'^  final Color (\w+);', multiLine: true),
          RegExp(r'^  final List<Color> (\w+);', multiLine: true),
        ],
      );
      final Map<String, Object?> scheme = (PrismTokenExport.build()['color']!
          as Map<String, Object?>)['scheme']! as Map<String, Object?>;

      expect(declared, isNotEmpty);
      for (final String appearance in <String>['light', 'dark']) {
        final Map<String, Object?> resolved = scheme[appearance]! as Map<String, Object?>;
        final Set<String> exported = <String>{
          ...(resolved['roles']! as Map<String, Object?>).keys,
          ...(resolved['roleSets']! as Map<String, Object?>).keys,
        };
        expect(
          declared.difference(exported),
          isEmpty,
          reason: 'Ces rôles sont déclarés dans prism_color_scheme.dart mais '
              'absents de l\'apparence "$appearance".\n'
              'Un rôle manquant oblige la plateforme native à le re-dériver, '
              'ce qui est la faute documentée par '
              'prism_contrast_contract_test.dart.',
        );
      }
    });
  });
}
