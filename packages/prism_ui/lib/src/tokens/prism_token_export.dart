import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import 'prism_colors.dart';
import 'prism_elevation.dart';
import 'prism_layout.dart';
import 'prism_motion.dart';
import 'prism_radii.dart';
import 'prism_spacing.dart';
import 'prism_state.dart';
import 'prism_typography.dart';

/// Projette les tokens Prism dans une structure **neutre**, sérialisable en
/// JSON, consommable par une plateforme qui n'est pas Flutter.
///
/// ## Pourquoi ce fichier existe
///
/// Le produit part en natif : iOS d'abord, Android plus tard. Deux applications
/// qui redéclarent chacune leur palette divergent — pas par négligence, mais
/// parce qu'une correction faite d'un côté n'a aucun chemin pour atteindre
/// l'autre. Cette projection est ce chemin.
///
/// ## Le sens de la dérivation : Dart reste la source
///
/// Le JSON est **généré**, jamais édité à la main. La direction inverse a été
/// examinée et écartée pour une raison mesurable : les fichiers de
/// `lib/src/tokens/` portent ~450 lignes de *raisonnement* — la loi de
/// dérivation OKLCH, les ratios de contraste mesurés, pourquoi le bleu Fluent a
/// été abandonné comme couleur de marque, pourquoi un chroma constant a été
/// rejeté. Un JSON ne peut pas porter cela sans devenir illisible, et le
/// générer depuis le JSON reviendrait à effacer la mémoire du design system.
/// S'y ajoute que les 263 tests du paquet, dont les trois gardes sémantiques de
/// `test/theme/`, lisent le Dart directement : inverser la dérivation
/// interposerait un générateur entre une garde et la valeur qu'elle garde.
///
/// La projection, elle, est **mécanique** : 88 couleurs plates, zéro dérivation
/// à l'exécution. Elle est donc sûre dans ce sens-là, et seulement dans
/// celui-là.
///
/// ## Ce qui est exporté, et pourquoi ce n'est pas la palette brute
///
/// [PrismColorScheme] le dit sans ambiguïté : *« This is the layer UI code
/// should depend on — never the raw [PrismColors]. »* Un export limité aux
/// primitives obligerait Swift et Kotlin à **re-dériver à la main** la
/// correspondance rôle → couleur par apparence.
///
/// Ce n'est pas une hypothèse : c'est exactement la régression qu'a documentée
/// `test/theme/prism_contrast_contract_test.dart`. Les tests vérifiaient les
/// primitives et jamais les rôles résolus, et six accents sur sept sont tombés
/// entre 2.6:1 et 3.1:1 en mode sombre. Exporter les seules primitives
/// reviendrait à livrer ce piège à deux plateformes de plus.
///
/// L'export porte donc les **rôles sémantiques résolus**, clair et sombre,
/// *en plus* des primitives.
///
/// ## Forme du JSON
///
/// Chaque groupe terminal est une table homogène (`String` → une seule sorte de
/// valeur), ce qui se décode en Swift avec un `Codable` sans traitement
/// spécial, et en Kotlin avec `kotlinx.serialization`. Les couleurs sont des
/// chaînes `#AARRGGBB` — la transcription directe du `Color(0xAARRGGBB)` Dart,
/// donc une revue de diff reste lisible.
@immutable
class PrismTokenExport {
  const PrismTokenExport._();

  /// Génération du format neutre. Incrémentée si la *forme* du document change
  /// d'une manière qu'un consommateur ne peut pas absorber.
  static const int schemaVersion = 1;

  /// Encodage des couleurs, publié dans le document pour qu'un consommateur
  /// n'ait pas à le deviner.
  static const String colorEncoding = '#AARRGGBB';

  /// Couleurs sentinelles servant à **mesurer** quel rôle de texte alimente
  /// chaque créneau typographique, au lieu de le supposer.
  ///
  /// [PrismTheme] appelle `PrismTypography.build(p.textPrimary,
  /// p.textSecondary)`. En construisant le thème typographique avec deux
  /// valeurs impossibles à confondre, on lit la réponse dans le résultat plutôt
  /// que de la recopier depuis le code source — qui pourrait changer.
  static const Color _probePrimary = Color(0xFF000001);
  static const Color _probeSecondary = Color(0xFF000002);

  /// Le document neutre complet, prêt à être encodé en JSON.
  static Map<String, Object?> build() {
    return <String, Object?>{
      'tokenSchemaVersion': schemaVersion,
      'colorEncoding': colorEncoding,
      'source': 'packages/prism_ui/lib/src/tokens',
      'generator': 'packages/prism_ui/lib/src/tokens/prism_token_export.dart',
      'color': _color(),
      'typography': _typography(),
      'spacing': _spacing(),
      'radii': _radii(),
      'layout': _layout(),
      'motion': _motion(),
      'elevation': _elevation(),
      'state': _state(),
    };
  }

  // ---- Couleur -----------------------------------------------------------

  static Map<String, Object?> _color() {
    return <String, Object?>{
      'primitive': _primitives(),
      'primitiveSets': _primitiveSets(),
      'scheme': <String, Object?>{
        'light': _scheme(PrismColorScheme.light),
        'dark': _scheme(PrismColorScheme.dark),
      },
    };
  }

  static Map<String, String> _primitives() {
    return <String, String>{
      'primary': hex(PrismColors.primary),
      'primaryDark': hex(PrismColors.primaryDark),
      'primarySoft': hex(PrismColors.primarySoft),
      'primarySoftDark': hex(PrismColors.primarySoftDark),
      'primaryVivid': hex(PrismColors.primaryVivid),
      'primaryGlow': hex(PrismColors.primaryGlow),
      'ember': hex(PrismColors.ember),
      'emberVivid': hex(PrismColors.emberVivid),
      'emberGlow': hex(PrismColors.emberGlow),
      'emberSoft': hex(PrismColors.emberSoft),
      'xpGold': hex(PrismColors.xpGold),
      'xpGoldVivid': hex(PrismColors.xpGoldVivid),
      'xpGoldGlow': hex(PrismColors.xpGoldGlow),
      'xpGoldSoft': hex(PrismColors.xpGoldSoft),
      'medalSilver': hex(PrismColors.medalSilver),
      'medalSilverGlow': hex(PrismColors.medalSilverGlow),
      'medalBronze': hex(PrismColors.medalBronze),
      'medalBronzeGlow': hex(PrismColors.medalBronzeGlow),
      'success': hex(PrismColors.success),
      'successVivid': hex(PrismColors.successVivid),
      'successGlow': hex(PrismColors.successGlow),
      'successSoft': hex(PrismColors.successSoft),
      'successSoftDark': hex(PrismColors.successSoftDark),
      'warning': hex(PrismColors.warning),
      'warningVivid': hex(PrismColors.warningVivid),
      'warningGlow': hex(PrismColors.warningGlow),
      'warningSoft': hex(PrismColors.warningSoft),
      'warningSoftDark': hex(PrismColors.warningSoftDark),
      'error': hex(PrismColors.error),
      'errorVivid': hex(PrismColors.errorVivid),
      'errorGlow': hex(PrismColors.errorGlow),
      'errorSoft': hex(PrismColors.errorSoft),
      'errorSoftDark': hex(PrismColors.errorSoftDark),
      'info': hex(PrismColors.info),
      'infoVivid': hex(PrismColors.infoVivid),
      'infoGlow': hex(PrismColors.infoGlow),
      'infoSoft': hex(PrismColors.infoSoft),
      'infoSoftDark': hex(PrismColors.infoSoftDark),
      'lightBg': hex(PrismColors.lightBg),
      'lightSurface': hex(PrismColors.lightSurface),
      'lightSurfaceAlt': hex(PrismColors.lightSurfaceAlt),
      'lightTextPrimary': hex(PrismColors.lightTextPrimary),
      'lightTextSecondary': hex(PrismColors.lightTextSecondary),
      'lightTextDisabled': hex(PrismColors.lightTextDisabled),
      'lightBorder': hex(PrismColors.lightBorder),
      'lightBorderStrong': hex(PrismColors.lightBorderStrong),
      'darkBg': hex(PrismColors.darkBg),
      'darkSurface': hex(PrismColors.darkSurface),
      'darkSurfaceAlt': hex(PrismColors.darkSurfaceAlt),
      'darkTextPrimary': hex(PrismColors.darkTextPrimary),
      'darkTextSecondary': hex(PrismColors.darkTextSecondary),
      'darkTextDisabled': hex(PrismColors.darkTextDisabled),
      'darkBorder': hex(PrismColors.darkBorder),
      'darkBorderStrong': hex(PrismColors.darkBorderStrong),
      'glassLightFill': hex(PrismColors.glassLightFill),
      'glassLightStroke': hex(PrismColors.glassLightStroke),
      'glassDarkFill': hex(PrismColors.glassDarkFill),
      'glassDarkStroke': hex(PrismColors.glassDarkStroke),
      'glassDarkLitEdge': hex(PrismColors.glassDarkLitEdge),
      'azureTrack': hex(PrismColors.azureTrack),
    };
  }

  static Map<String, List<String>> _primitiveSets() {
    return <String, List<String>>{
      'spectrumInk': _hexList(PrismColors.spectrumInk),
      'spectrumVivid': _hexList(PrismColors.spectrumVivid),
      'spectrumGlow': _hexList(PrismColors.spectrumGlow),
      'spectrumSoftLight': _hexList(PrismColors.spectrumSoftLight),
      'spectrumSoftDark': _hexList(PrismColors.spectrumSoftDark),
      'domainAccents': _hexList(PrismColors.domainAccents),
    };
  }

  /// Les rôles **résolus** d'une apparence — ce qu'un site d'appel lit
  /// réellement, et donc ce qu'une app native doit consommer.
  static Map<String, Object?> _scheme(PrismColorScheme p) {
    return <String, Object?>{
      'brightness': p.brightness.name,
      'roles': <String, String>{
        'primary': hex(p.primary),
        'primaryFill': hex(p.primaryFill),
        'primaryDark': hex(p.primaryDark),
        'primarySoft': hex(p.primarySoft),
        'primaryVivid': hex(p.primaryVivid),
        'primaryOnSurface': hex(p.primaryOnSurface),
        'onPrimary': hex(p.onPrimary),
        'ember': hex(p.ember),
        'emberFill': hex(p.emberFill),
        'emberOnSurface': hex(p.emberOnSurface),
        'emberSoft': hex(p.emberSoft),
        'xpGold': hex(p.xpGold),
        'xpGoldFill': hex(p.xpGoldFill),
        'xpGoldOnSurface': hex(p.xpGoldOnSurface),
        'xpGoldSoft': hex(p.xpGoldSoft),
        'success': hex(p.success),
        'successFill': hex(p.successFill),
        'successOnSurface': hex(p.successOnSurface),
        'successSoft': hex(p.successSoft),
        'warning': hex(p.warning),
        'warningFill': hex(p.warningFill),
        'warningOnSurface': hex(p.warningOnSurface),
        'warningSoft': hex(p.warningSoft),
        'error': hex(p.error),
        'errorFill': hex(p.errorFill),
        'errorOnSurface': hex(p.errorOnSurface),
        'errorSoft': hex(p.errorSoft),
        'info': hex(p.info),
        'infoFill': hex(p.infoFill),
        'infoOnSurface': hex(p.infoOnSurface),
        'infoSoft': hex(p.infoSoft),
        'background': hex(p.background),
        'surface': hex(p.surface),
        'surfaceAlt': hex(p.surfaceAlt),
        'textPrimary': hex(p.textPrimary),
        'textSecondary': hex(p.textSecondary),
        'textDisabled': hex(p.textDisabled),
        'border': hex(p.border),
        'borderStrong': hex(p.borderStrong),
        'glassFill': hex(p.glassFill),
        'glassStroke': hex(p.glassStroke),
        'litEdge': hex(p.litEdge),
        'focusRing': hex(p.focusRing),
      },
      'roleSets': <String, List<String>>{
        'domainAccents': _hexList(p.domainAccents),
        'domainAccentsFill': _hexList(p.domainAccentsFill),
        'domainAccentsVivid': _hexList(p.domainAccentsVivid),
        'domainAccentsOnSurface': _hexList(p.domainAccentsOnSurface),
        'domainAccentsSoft': _hexList(p.domainAccentsSoft),
        'medalTones': _hexList(p.medalTones),
      },
    };
  }

  // ---- Typographie -------------------------------------------------------

  static Map<String, Object?> _typography() {
    final TextTheme text = PrismTypography.build(_probePrimary, _probeSecondary);
    final TextStyle mono = PrismTypography.mono(_probePrimary);

    return <String, Object?>{
      'families': <String, String>{
        'ui': 'Archivo',
        'mono': 'JetBrainsMono',
        'legacyDisplay': PrismTypography.legacyDisplayFontFamily,
        'legacyBody': PrismTypography.legacyBodyFontFamily,
        'brandIcons': 'FontAwesomeBrands',
      },
      'styles': <String, Object?>{
        'displayLarge': _style(text.displayLarge),
        'displayMedium': _style(text.displayMedium),
        'displaySmall': _style(text.displaySmall),
        'headlineLarge': _style(text.headlineLarge),
        'headlineMedium': _style(text.headlineMedium),
        'headlineSmall': _style(text.headlineSmall),
        'titleLarge': _style(text.titleLarge),
        'titleMedium': _style(text.titleMedium),
        'titleSmall': _style(text.titleSmall),
        'bodyLarge': _style(text.bodyLarge),
        'bodyMedium': _style(text.bodyMedium),
        'bodySmall': _style(text.bodySmall),
        'labelLarge': _style(text.labelLarge),
        'labelMedium': _style(text.labelMedium),
        'labelSmall': _style(text.labelSmall),
        'mono': _style(mono),
      },
    };
  }

  /// Un créneau typographique, réduit à ce qu'une plateforme sait appliquer.
  ///
  /// `colorRole` est **mesuré** via les sentinelles plutôt que recopié : le
  /// document ne peut donc pas affirmer qu'un créneau est secondaire alors que
  /// le code le construit en primaire.
  static Map<String, Object?> _style(TextStyle? style) {
    if (style == null) {
      return <String, Object?>{};
    }
    return <String, Object?>{
      'fontFamily': style.fontFamily?.split('/').last ?? '',
      'fontSize': style.fontSize,
      'fontWeight': style.fontWeight?.value,
      'wght': _axis(style, 'wght'),
      'wdth': _axis(style, 'wdth'),
      'lineHeight': style.height,
      'letterSpacing': style.letterSpacing ?? 0,
      'colorRole': _colorRole(style.color),
    };
  }

  static double? _axis(TextStyle style, String tag) {
    for (final FontVariation variation in style.fontVariations ?? const <FontVariation>[]) {
      if (variation.axis == tag) {
        return variation.value;
      }
    }
    return null;
  }

  static String _colorRole(Color? color) {
    if (color == _probePrimary) {
      return 'textPrimary';
    }
    if (color == _probeSecondary) {
      return 'textSecondary';
    }
    return 'unspecified';
  }

  // ---- Géométrie ---------------------------------------------------------

  static Map<String, Object?> _spacing() {
    return <String, Object?>{
      'scale': <String, double>{
        'xxs': PrismSpacing.xxs,
        'xs': PrismSpacing.xs,
        'sm': PrismSpacing.sm,
        'md': PrismSpacing.md,
        'lg': PrismSpacing.lg,
        'xl': PrismSpacing.xl,
        'xxl': PrismSpacing.xxl,
        'xxxl': PrismSpacing.xxxl,
      },
      'semantic': <String, double>{
        'gutter': PrismSpacing.gutter,
        'cardInset': PrismSpacing.cardInset,
        'bottomNavClearance': PrismSpacing.bottomNavClearance,
      },
      // Publiée pour que le portage natif hérite de la dette au lieu de la
      // réinventer sans le savoir. Voir `prism_spacing.dart` : ces valeurs sont
      // hors grille 4pt et attendent une passe de design.
      'debt': <String, double>{
        'debt3': PrismSpacing.debt3,
        'debt6': PrismSpacing.debt6,
        'debt7': PrismSpacing.debt7,
        'debt9': PrismSpacing.debt9,
        'debt10': PrismSpacing.debt10,
        'debt11': PrismSpacing.debt11,
        'debt14': PrismSpacing.debt14,
        'debt28': PrismSpacing.debt28,
        'debt30': PrismSpacing.debt30,
      },
    };
  }

  static Map<String, Object?> _radii() {
    return <String, Object?>{
      'scale': <String, double>{
        'sm': PrismRadii.sm,
        'md': PrismRadii.md,
        'lg': PrismRadii.lg,
        'xl': PrismRadii.xl,
        'xxl': PrismRadii.xxl,
        'button': PrismRadii.button,
        'pill': PrismRadii.pill,
      },
      'debt': <String, double>{
        'debt3': PrismRadii.debt3,
        'debt26': PrismRadii.debt26,
        'debt28': PrismRadii.debt28,
      },
    };
  }

  static Map<String, Object?> _layout() {
    return <String, Object?>{
      'readingWidths': <String, double>{
        'compact': PrismLayout.compact,
        'form': PrismLayout.form,
        'panel': PrismLayout.panel,
        'controlBar': PrismLayout.controlBar,
        'reading': PrismLayout.reading,
        'canvas': PrismLayout.canvas,
        'workspace': PrismLayout.workspace,
      },
      'scale': PrismLayout.scale,
    };
  }

  // ---- Mouvement ---------------------------------------------------------

  static Map<String, Object?> _motion() {
    return <String, Object?>{
      'durationsMs': <String, int>{
        'instant': PrismMotion.instant.inMilliseconds,
        'fast': PrismMotion.fast.inMilliseconds,
        'base': PrismMotion.base.inMilliseconds,
        'slow': PrismMotion.slow.inMilliseconds,
        'celebrate': PrismMotion.celebrate.inMilliseconds,
        'state': PrismMotion.state.inMilliseconds,
        'morph': PrismMotion.morph.inMilliseconds,
      },
      'curves': <String, Object?>{
        'standard': _curve(PrismMotion.standard),
        'emphasized': _curve(PrismMotion.emphasized),
        'spring': _curve(PrismMotion.spring),
        'decelerate': _curve(PrismMotion.decelerate),
        'continuous': _curve(PrismMotion.continuous),
      },
      // Invariant du dépôt, pas une suggestion : le mouvement est informatif.
      // Une plateforme qui ignore la préférence système trahit le contrat.
      'reducedMotionCollapsesToZero': true,
    };
  }

  static Map<String, double> _curve(Curve curve) {
    final Cubic cubic = curve as Cubic;
    return <String, double>{'x1': cubic.a, 'y1': cubic.b, 'x2': cubic.c, 'y2': cubic.d};
  }

  // ---- Profondeur --------------------------------------------------------

  static Map<String, Object?> _elevation() {
    return <String, Object?>{
      'light': _elevationFor(Brightness.light),
      'dark': _elevationFor(Brightness.dark),
    };
  }

  static Map<String, Object?> _elevationFor(Brightness brightness) {
    return <String, Object?>{
      'level0': _shadows(PrismElevation.level0),
      'level1': _shadows(PrismElevation.level1(brightness)),
      'level2': _shadows(PrismElevation.level2(brightness)),
      'level3': _shadows(PrismElevation.level3(brightness)),
    };
  }

  static List<Map<String, Object?>> _shadows(List<BoxShadow> shadows) {
    return <Map<String, Object?>>[
      for (final BoxShadow shadow in shadows)
        <String, Object?>{
          'color': hex(shadow.color),
          'offsetX': shadow.offset.dx,
          'offsetY': shadow.offset.dy,
          'blurRadius': shadow.blurRadius,
          'spreadRadius': shadow.spreadRadius,
        },
    ];
  }

  // ---- États d'interaction ----------------------------------------------

  static Map<String, Object?> _state() {
    return <String, Object?>{
      'light': _stateFor(Brightness.light),
      'dark': _stateFor(Brightness.dark),
      'constants': <String, double>{
        'disabledSurface': PrismStateLayer.disabledSurface,
        'pressedScale': PrismStateLayer.pressedScale,
      },
      'focusRing': <String, double>{
        'width': PrismFocusRing.width,
        'gap': PrismFocusRing.gap,
        'inset': PrismFocusRing.inset,
      },
    };
  }

  static Map<String, double> _stateFor(Brightness brightness) {
    return <String, double>{
      'hover': PrismStateLayer.hover(brightness),
      'pressed': PrismStateLayer.pressed(brightness),
      'selected': PrismStateLayer.selected(brightness),
      'focusHalo': PrismStateLayer.focusHalo(brightness),
      'disabledContent': PrismStateLayer.disabledContent(brightness),
    };
  }

  // ---- Encodage ----------------------------------------------------------

  /// Transcrit une couleur en `#AARRGGBB`, la forme directe du littéral Dart.
  static String hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static List<String> _hexList(List<Color> colors) =>
      <String>[for (final Color color in colors) hex(color)];
}
