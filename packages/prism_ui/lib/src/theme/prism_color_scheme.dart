import 'package:flutter/material.dart';
import '../tokens/prism_colors.dart';

/// Semantic color roles for Microlingo, exposed as a [ThemeExtension] so any
/// widget can read `Theme.of(context).extension<PrismColorScheme>()` (or the
/// `context.prism` helper) and stay correct in light *and* dark mode.
///
/// This is the layer UI code should depend on — never the raw [PrismColors].
@immutable
class PrismColorScheme extends ThemeExtension<PrismColorScheme> {
  const PrismColorScheme({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.ember,
    required this.xpGold,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.glassFill,
    required this.glassStroke,
    required this.domainAccents,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color ember;
  final Color xpGold;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color glassFill;
  final Color glassStroke;
  final List<Color> domainAccents;

  /// Deterministic accent for an exam domain by index.
  Color accentFor(int domainIndex) => domainAccents[domainIndex % domainAccents.length];

  static const PrismColorScheme light = PrismColorScheme(
    brightness: Brightness.light,
    primary: PrismColors.primary,
    primaryDark: PrismColors.primaryDark,
    primarySoft: PrismColors.primarySoft,
    ember: PrismColors.ember,
    xpGold: PrismColors.xpGold,
    success: PrismColors.success,
    warning: PrismColors.warning,
    error: PrismColors.error,
    info: PrismColors.info,
    background: PrismColors.lightBg,
    surface: PrismColors.lightSurface,
    surfaceAlt: PrismColors.lightSurfaceAlt,
    textPrimary: PrismColors.lightTextPrimary,
    textSecondary: PrismColors.lightTextSecondary,
    border: PrismColors.lightBorder,
    glassFill: PrismColors.glassLightFill,
    glassStroke: PrismColors.glassLightStroke,
    domainAccents: PrismColors.domainAccents,
  );

  static const PrismColorScheme dark = PrismColorScheme(
    brightness: Brightness.dark,
    primary: PrismColors.primary,
    primaryDark: PrismColors.primaryDark,
    primarySoft: Color(0xFF1E2C52),
    ember: PrismColors.ember,
    xpGold: PrismColors.xpGold,
    success: PrismColors.success,
    warning: PrismColors.warning,
    error: PrismColors.error,
    info: PrismColors.info,
    background: PrismColors.darkBg,
    surface: PrismColors.darkSurface,
    surfaceAlt: PrismColors.darkSurfaceAlt,
    textPrimary: PrismColors.darkTextPrimary,
    textSecondary: PrismColors.darkTextSecondary,
    border: PrismColors.darkBorder,
    glassFill: PrismColors.glassDarkFill,
    glassStroke: PrismColors.glassDarkStroke,
    domainAccents: PrismColors.domainAccents,
  );

  @override
  PrismColorScheme copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryDark,
    Color? primarySoft,
    Color? ember,
    Color? xpGold,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? glassFill,
    Color? glassStroke,
    List<Color>? domainAccents,
  }) {
    return PrismColorScheme(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      ember: ember ?? this.ember,
      xpGold: xpGold ?? this.xpGold,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      glassFill: glassFill ?? this.glassFill,
      glassStroke: glassStroke ?? this.glassStroke,
      domainAccents: domainAccents ?? this.domainAccents,
    );
  }

  @override
  PrismColorScheme lerp(ThemeExtension<PrismColorScheme>? other, double t) {
    if (other is! PrismColorScheme) return this;
    return PrismColorScheme(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      xpGold: Color.lerp(xpGold, other.xpGold, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassStroke: Color.lerp(glassStroke, other.glassStroke, t)!,
      domainAccents: t < 0.5 ? domainAccents : other.domainAccents,
    );
  }
}

/// Ergonomic access: `context.prism.primary`.
extension PrismThemeX on BuildContext {
  PrismColorScheme get prism =>
      Theme.of(this).extension<PrismColorScheme>() ?? PrismColorScheme.light;
}
