import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Contrat typographique : **tout** créneau de [TextTheme] doit être possédé
/// par Prism.
///
/// Pourquoi ce test existe — le piège qu'il ferme :
///
/// [ThemeData] ne *remplace* pas le `textTheme` qu'on lui passe, il le
/// **fusionne** par-dessus la [Typography] de la plateforme. Un créneau que
/// [PrismTypography.build] ne définit pas n'est donc pas vide : il est
/// silencieusement rempli par Material, et hérite de la police, de la taille
/// ET de la graisse du système — `CupertinoSystemDisplay` sur iOS, `Roboto`
/// sur Android.
///
/// Rien ne le signale. `Theme.of(context).textTheme.headlineSmall` compile,
/// s'affiche, et échappe entièrement au design system. C'est ainsi que le
/// titre héros de l'écran d'ouverture s'est retrouvé en police système
/// (audit visuel du 2026-09-10 : `displaySmall`, `headlineLarge` et
/// `headlineSmall` non définis, utilisés par onze appels dont
/// `landing_screen.dart`).
///
/// L'assertion porte sur le **préfixe de paquet**, pas sur le nom de la
/// fonte : renommer ou remplacer la famille de marque (PlusJakartaSans →
/// Archivo, par exemple) garde le test vert, tandis qu'un créneau qui retombe
/// sur la police système le fait rougir. C'est le contrat qui est verrouillé,
/// pas le choix esthétique.
void main() {
  /// Préfixe que Flutter appose aux familles déclarées par un paquet. Toute
  /// famille servie par `prism_ui` le porte ; aucune police système ne l'a.
  const String brandPrefix = 'packages/prism_ui/';

  /// Les 15 créneaux de [TextTheme]. Ils sont TOUS listés volontairement :
  /// un créneau « qu'on n'utilise pas » reste atteignable depuis n'importe
  /// quel écran et constitue exactement le piège décrit ci-dessus.
  const Map<String, TextStyle? Function(TextTheme)> slots =
      <String, TextStyle? Function(TextTheme)>{
    'displayLarge': _displayLarge,
    'displayMedium': _displayMedium,
    'displaySmall': _displaySmall,
    'headlineLarge': _headlineLarge,
    'headlineMedium': _headlineMedium,
    'headlineSmall': _headlineSmall,
    'titleLarge': _titleLarge,
    'titleMedium': _titleMedium,
    'titleSmall': _titleSmall,
    'bodyLarge': _bodyLarge,
    'bodyMedium': _bodyMedium,
    'bodySmall': _bodySmall,
    'labelLarge': _labelLarge,
    'labelMedium': _labelMedium,
    'labelSmall': _labelSmall,
  };

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final TargetPlatform platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    for (final MapEntry<String, ThemeData Function()> theme in <String, ThemeData Function()>{
      'clair': PrismTheme.light,
      'sombre': PrismTheme.dark,
    }.entries) {
      group('${platform.name} — thème ${theme.key}', () {
        for (final MapEntry<String, TextStyle? Function(TextTheme)> slot in slots.entries) {
          test('${slot.key} est défini par Prism', () {
            // Doit être posé AVANT de construire le thème : c'est ce qui
            // détermine la Typography que ThemeData fusionne dessous.
            debugDefaultTargetPlatformOverride = platform;
            final TextTheme text = theme.value().textTheme;
            final TextStyle? style = slot.value(text);

            expect(style, isNotNull, reason: '${slot.key} est absent du TextTheme.');
            expect(
              style!.fontFamily,
              isNotNull,
              reason: '${slot.key} n\'a aucune famille de police.',
            );
            expect(
              style.fontFamily,
              startsWith(brandPrefix),
              reason: '${slot.key} retombe sur la police du système ("${style.fontFamily}") '
                  'au lieu d\'une famille servie par prism_ui. '
                  'Cause : PrismTypography.build() ne définit pas ce créneau, '
                  'et ThemeData le remplit depuis la Typography de la plateforme. '
                  'Correctif : ajouter ${slot.key} dans PrismTypography.build().',
            );
            expect(
              style.fontSize,
              isNotNull,
              reason: '${slot.key} n\'a pas de taille Prism : il hérite de celle de Material. '
                  'Ajouter ${slot.key} dans PrismTypography.build().',
            );
            expect(
              style.fontWeight,
              isNotNull,
              reason: '${slot.key} n\'a pas de graisse Prism : il hérite de celle de Material. '
                  'Ajouter ${slot.key} dans PrismTypography.build().',
            );
          });
        }
      });
    }
  }
}

TextStyle? _displayLarge(TextTheme t) => t.displayLarge;
TextStyle? _displayMedium(TextTheme t) => t.displayMedium;
TextStyle? _displaySmall(TextTheme t) => t.displaySmall;
TextStyle? _headlineLarge(TextTheme t) => t.headlineLarge;
TextStyle? _headlineMedium(TextTheme t) => t.headlineMedium;
TextStyle? _headlineSmall(TextTheme t) => t.headlineSmall;
TextStyle? _titleLarge(TextTheme t) => t.titleLarge;
TextStyle? _titleMedium(TextTheme t) => t.titleMedium;
TextStyle? _titleSmall(TextTheme t) => t.titleSmall;
TextStyle? _bodyLarge(TextTheme t) => t.bodyLarge;
TextStyle? _bodyMedium(TextTheme t) => t.bodyMedium;
TextStyle? _bodySmall(TextTheme t) => t.bodySmall;
TextStyle? _labelLarge(TextTheme t) => t.labelLarge;
TextStyle? _labelMedium(TextTheme t) => t.labelMedium;
TextStyle? _labelSmall(TextTheme t) => t.labelSmall;
