import 'package:flutter/material.dart';
import '../tokens/prism_colors.dart';
import '../tokens/prism_state.dart';

/// Semantic color roles for Certigo, exposed as a [ThemeExtension] so any
/// widget can read `Theme.of(context).extension<PrismColorScheme>()` (or the
/// `context.prism` helper) and stay correct in light *and* dark mode.
///
/// This is the layer UI code should depend on — never the raw [PrismColors].
///
/// ## Three roles, not one colour
///
/// A single colour cannot be a fill, a label and a wash at once; pretending it
/// can is what forces a palette to compromise until nothing is quite legible.
/// Every accent here therefore appears in three roles:
///
/// * **fill** ([primary], [success], …) — a solid block that carries white
///   text. Identical in light and dark, because a fill sits on top of the
///   chrome rather than inside it.
/// * **onSurface** ([primaryOnSurface], [successOnSurface], …) — the same
///   accent as *text or icon* directly on the chrome. This one must flip
///   between modes: the ink that reads on a light canvas disappears on a dark
///   one.
/// * **soft** ([primarySoft], [successSoft], …) — a wash for tinting a whole
///   region in the accent's hue, which is how a track colours its own area.
@immutable
class PrismColorScheme extends ThemeExtension<PrismColorScheme> {
  const PrismColorScheme({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryVivid,
    required this.primaryOnSurface,
    required this.onPrimary,
    required this.ember,
    required this.emberOnSurface,
    required this.emberSoft,
    required this.xpGold,
    required this.xpGoldOnSurface,
    required this.xpGoldSoft,
    required this.success,
    required this.successOnSurface,
    required this.successSoft,
    required this.warning,
    required this.warningOnSurface,
    required this.warningSoft,
    required this.error,
    required this.errorOnSurface,
    required this.errorSoft,
    required this.info,
    required this.infoOnSurface,
    required this.infoSoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
    required this.glassFill,
    required this.glassStroke,
    required this.litEdge,
    required this.domainAccents,
    required this.domainAccentsVivid,
    required this.domainAccentsOnSurface,
    required this.domainAccentsSoft,
  });

  final Brightness brightness;

  /// Solid brand fill for primary actions. Carries white text.
  final Color primary;

  /// Darker brand tone: gradient bottom, pressed lip.
  final Color primaryDark;

  /// Brand wash for tinting a region.
  final Color primarySoft;

  /// Vivid brand tone for progress, rings and glows. Not a body-text colour.
  final Color primaryVivid;

  /// Brand as text or icon directly on the chrome.
  final Color primaryOnSurface;

  /// Foreground on top of [primary] and the other fills.
  final Color onPrimary;

  final Color ember;
  final Color emberOnSurface;
  final Color emberSoft;
  final Color xpGold;
  final Color xpGoldOnSurface;
  final Color xpGoldSoft;
  final Color success;
  final Color successOnSurface;
  final Color successSoft;
  final Color warning;
  final Color warningOnSurface;
  final Color warningSoft;
  final Color error;
  final Color errorOnSurface;
  final Color errorSoft;
  final Color info;
  final Color infoOnSurface;
  final Color infoSoft;

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;

  /// Text of a disabled control. Still clears 3:1 — disabled must read as
  /// unavailable, never as a rendering fault.
  final Color textDisabled;

  final Color border;

  /// Firmer edge for controls that must read as tappable at a glance.
  final Color borderStrong;

  final Color glassFill;
  final Color glassStroke;

  /// Directional top highlight on glass. Transparent in light mode by design:
  /// a white lit edge over a light fill measures 1.00:1 and is pure noise, so
  /// light chrome carries depth with shadow and a darker edge instead.
  final Color litEdge;

  /// Ink role per exam domain — body-text legible.
  final List<Color> domainAccents;

  /// Vivid role per exam domain — rings, progress, fills.
  final List<Color> domainAccentsVivid;

  /// Per-domain accent as text on the current chrome.
  final List<Color> domainAccentsOnSurface;

  /// Per-domain wash, for a track colouring its own region.
  final List<Color> domainAccentsSoft;

  /// Deterministic accent for an exam domain by index.
  Color accentFor(int domainIndex) => domainAccents[domainIndex % domainAccents.length];

  /// Vivid accent for an exam domain — fills, rings, progress.
  Color accentVividFor(int domainIndex) =>
      domainAccentsVivid[domainIndex % domainAccentsVivid.length];

  /// Accent for an exam domain as text or icon on the current chrome.
  Color accentOnSurfaceFor(int domainIndex) =>
      domainAccentsOnSurface[domainIndex % domainAccentsOnSurface.length];

  /// Wash for an exam domain, for tinting its whole region.
  Color accentSoftFor(int domainIndex) => domainAccentsSoft[domainIndex % domainAccentsSoft.length];

  // ---- Interaction state layers -----------------------------------------
  // One vocabulary, resolved against whichever surface the control sits on.

  /// Rest -> hover. The state that did not exist before: both pressables set
  /// `overlayColor: Colors.transparent`, so nothing responded to a pointer.
  Color hoverOn(Color base, {Color? tint}) => Color.alphaBlend(
      (tint ?? primaryVivid).withValues(alpha: PrismStateLayer.hover(brightness)), base);

  Color pressedOn(Color base, {Color? tint}) => Color.alphaBlend(
        (tint ?? primaryVivid).withValues(alpha: PrismStateLayer.pressed(brightness)),
        base,
      );

  Color selectedOn(Color base, {Color? tint}) => Color.alphaBlend(
        (tint ?? primaryVivid).withValues(alpha: PrismStateLayer.selected(brightness)),
        base,
      );

  Color focusHaloOn(Color base, {Color? tint}) => Color.alphaBlend(
        (tint ?? primaryVivid).withValues(alpha: PrismStateLayer.focusHalo(brightness)),
        base,
      );

  /// The single focus ring colour. One ring, themed, everywhere.
  Color get focusRing => primaryOnSurface;

  static const PrismColorScheme light = PrismColorScheme(
    brightness: Brightness.light,
    primary: PrismColors.primary,
    primaryDark: PrismColors.primaryDark,
    primarySoft: PrismColors.primarySoft,
    primaryVivid: PrismColors.primaryVivid,
    primaryOnSurface: PrismColors.primary,
    onPrimary: Color(0xFFFFFFFF),
    ember: PrismColors.ember,
    emberOnSurface: PrismColors.ember,
    emberSoft: PrismColors.emberSoft,
    xpGold: PrismColors.xpGold,
    xpGoldOnSurface: PrismColors.xpGold,
    xpGoldSoft: PrismColors.xpGoldSoft,
    success: PrismColors.success,
    successOnSurface: PrismColors.success,
    successSoft: PrismColors.successSoft,
    warning: PrismColors.warning,
    warningOnSurface: PrismColors.warning,
    warningSoft: PrismColors.warningSoft,
    error: PrismColors.error,
    errorOnSurface: PrismColors.error,
    errorSoft: PrismColors.errorSoft,
    info: PrismColors.info,
    infoOnSurface: PrismColors.info,
    infoSoft: PrismColors.infoSoft,
    background: PrismColors.lightBg,
    surface: PrismColors.lightSurface,
    surfaceAlt: PrismColors.lightSurfaceAlt,
    textPrimary: PrismColors.lightTextPrimary,
    textSecondary: PrismColors.lightTextSecondary,
    textDisabled: PrismColors.lightTextDisabled,
    border: PrismColors.lightBorder,
    borderStrong: PrismColors.lightBorderStrong,
    glassFill: PrismColors.glassLightFill,
    glassStroke: PrismColors.glassLightStroke,
    litEdge: Color(0x00FFFFFF),
    domainAccents: PrismColors.spectrumInk,
    domainAccentsVivid: PrismColors.spectrumVivid,
    domainAccentsOnSurface: PrismColors.spectrumInk,
    domainAccentsSoft: PrismColors.spectrumSoftLight,
  );

  static const PrismColorScheme dark = PrismColorScheme(
    brightness: Brightness.dark,
    primary: PrismColors.primary,
    primaryDark: PrismColors.primaryDark,
    primarySoft: PrismColors.primarySoftDark,
    primaryVivid: PrismColors.primaryVivid,
    primaryOnSurface: PrismColors.primaryGlow,
    onPrimary: Color(0xFFFFFFFF),
    ember: PrismColors.ember,
    emberOnSurface: PrismColors.emberGlow,
    emberSoft: PrismColors.errorSoftDark,
    xpGold: PrismColors.xpGold,
    xpGoldOnSurface: PrismColors.xpGoldGlow,
    xpGoldSoft: PrismColors.warningSoftDark,
    success: PrismColors.success,
    successOnSurface: PrismColors.successGlow,
    successSoft: PrismColors.successSoftDark,
    warning: PrismColors.warning,
    warningOnSurface: PrismColors.warningGlow,
    warningSoft: PrismColors.warningSoftDark,
    error: PrismColors.error,
    errorOnSurface: PrismColors.errorGlow,
    errorSoft: PrismColors.errorSoftDark,
    info: PrismColors.info,
    infoOnSurface: PrismColors.infoGlow,
    infoSoft: PrismColors.infoSoftDark,
    background: PrismColors.darkBg,
    surface: PrismColors.darkSurface,
    surfaceAlt: PrismColors.darkSurfaceAlt,
    textPrimary: PrismColors.darkTextPrimary,
    textSecondary: PrismColors.darkTextSecondary,
    textDisabled: PrismColors.darkTextDisabled,
    border: PrismColors.darkBorder,
    borderStrong: PrismColors.darkBorderStrong,
    glassFill: PrismColors.glassDarkFill,
    glassStroke: PrismColors.glassDarkStroke,
    litEdge: PrismColors.glassDarkLitEdge,
    domainAccents: PrismColors.spectrumInk,
    domainAccentsVivid: PrismColors.spectrumVivid,
    domainAccentsOnSurface: PrismColors.spectrumGlow,
    domainAccentsSoft: PrismColors.spectrumSoftDark,
  );

  @override
  PrismColorScheme copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryDark,
    Color? primarySoft,
    Color? primaryVivid,
    Color? primaryOnSurface,
    Color? onPrimary,
    Color? ember,
    Color? emberOnSurface,
    Color? emberSoft,
    Color? xpGold,
    Color? xpGoldOnSurface,
    Color? xpGoldSoft,
    Color? success,
    Color? successOnSurface,
    Color? successSoft,
    Color? warning,
    Color? warningOnSurface,
    Color? warningSoft,
    Color? error,
    Color? errorOnSurface,
    Color? errorSoft,
    Color? info,
    Color? infoOnSurface,
    Color? infoSoft,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
    Color? borderStrong,
    Color? glassFill,
    Color? glassStroke,
    Color? litEdge,
    List<Color>? domainAccents,
    List<Color>? domainAccentsVivid,
    List<Color>? domainAccentsOnSurface,
    List<Color>? domainAccentsSoft,
  }) {
    return PrismColorScheme(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryVivid: primaryVivid ?? this.primaryVivid,
      primaryOnSurface: primaryOnSurface ?? this.primaryOnSurface,
      onPrimary: onPrimary ?? this.onPrimary,
      ember: ember ?? this.ember,
      emberOnSurface: emberOnSurface ?? this.emberOnSurface,
      emberSoft: emberSoft ?? this.emberSoft,
      xpGold: xpGold ?? this.xpGold,
      xpGoldOnSurface: xpGoldOnSurface ?? this.xpGoldOnSurface,
      xpGoldSoft: xpGoldSoft ?? this.xpGoldSoft,
      success: success ?? this.success,
      successOnSurface: successOnSurface ?? this.successOnSurface,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningOnSurface: warningOnSurface ?? this.warningOnSurface,
      warningSoft: warningSoft ?? this.warningSoft,
      error: error ?? this.error,
      errorOnSurface: errorOnSurface ?? this.errorOnSurface,
      errorSoft: errorSoft ?? this.errorSoft,
      info: info ?? this.info,
      infoOnSurface: infoOnSurface ?? this.infoOnSurface,
      infoSoft: infoSoft ?? this.infoSoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      glassFill: glassFill ?? this.glassFill,
      glassStroke: glassStroke ?? this.glassStroke,
      litEdge: litEdge ?? this.litEdge,
      domainAccents: domainAccents ?? this.domainAccents,
      domainAccentsVivid: domainAccentsVivid ?? this.domainAccentsVivid,
      domainAccentsOnSurface: domainAccentsOnSurface ?? this.domainAccentsOnSurface,
      domainAccentsSoft: domainAccentsSoft ?? this.domainAccentsSoft,
    );
  }

  @override
  PrismColorScheme lerp(ThemeExtension<PrismColorScheme>? other, double t) {
    if (other is! PrismColorScheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return PrismColorScheme(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: c(primary, other.primary),
      primaryDark: c(primaryDark, other.primaryDark),
      primarySoft: c(primarySoft, other.primarySoft),
      primaryVivid: c(primaryVivid, other.primaryVivid),
      primaryOnSurface: c(primaryOnSurface, other.primaryOnSurface),
      onPrimary: c(onPrimary, other.onPrimary),
      ember: c(ember, other.ember),
      emberOnSurface: c(emberOnSurface, other.emberOnSurface),
      emberSoft: c(emberSoft, other.emberSoft),
      xpGold: c(xpGold, other.xpGold),
      xpGoldOnSurface: c(xpGoldOnSurface, other.xpGoldOnSurface),
      xpGoldSoft: c(xpGoldSoft, other.xpGoldSoft),
      success: c(success, other.success),
      successOnSurface: c(successOnSurface, other.successOnSurface),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningOnSurface: c(warningOnSurface, other.warningOnSurface),
      warningSoft: c(warningSoft, other.warningSoft),
      error: c(error, other.error),
      errorOnSurface: c(errorOnSurface, other.errorOnSurface),
      errorSoft: c(errorSoft, other.errorSoft),
      info: c(info, other.info),
      infoOnSurface: c(infoOnSurface, other.infoOnSurface),
      infoSoft: c(infoSoft, other.infoSoft),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      glassFill: c(glassFill, other.glassFill),
      glassStroke: c(glassStroke, other.glassStroke),
      litEdge: c(litEdge, other.litEdge),
      domainAccents: t < 0.5 ? domainAccents : other.domainAccents,
      domainAccentsVivid: t < 0.5 ? domainAccentsVivid : other.domainAccentsVivid,
      domainAccentsOnSurface: t < 0.5 ? domainAccentsOnSurface : other.domainAccentsOnSurface,
      domainAccentsSoft: t < 0.5 ? domainAccentsSoft : other.domainAccentsSoft,
    );
  }
}

/// Ergonomic access: `context.prism.primary`.
extension PrismThemeX on BuildContext {
  PrismColorScheme get prism =>
      Theme.of(this).extension<PrismColorScheme>() ?? PrismColorScheme.light;
}
