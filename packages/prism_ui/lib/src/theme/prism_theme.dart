import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/prism_colors.dart';
import '../tokens/prism_radii.dart' show PrismRadii;
import '../tokens/prism_typography.dart';
import 'prism_color_scheme.dart';

/// Builds the Material [ThemeData] for Certigo from Prism tokens.
///
/// We lean on Material 3 for accessibility plumbing (touch targets, focus,
/// contrast) but override the surfaces, shapes and type so the result reads as
/// the bespoke "Prism" language rather than stock Material.
class PrismTheme {
  const PrismTheme._();

  static ThemeData light() => _build(PrismColorScheme.light);
  static ThemeData dark() => _build(PrismColorScheme.dark);

  static ThemeData _build(PrismColorScheme p) {
    final bool isDark = p.brightness == Brightness.dark;
    final TextTheme text = PrismTypography.build(p.textPrimary, p.textSecondary);

    final ColorScheme scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: Colors.white,
      secondary: p.ember,
      onSecondary: Colors.white,
      error: p.error,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceAlt,
      outline: p.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[p],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.textPrimary,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: PrismRadii.cardLg),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        side: BorderSide(color: p.border),
        labelStyle: text.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: PrismRadii.pillAll),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? PrismColors.darkSurfaceAlt : p.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: PrismRadii.cardMd),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(PrismRadii.xl)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceAlt,
        circularTrackColor: p.surfaceAlt,
      ),
    );
  }
}
