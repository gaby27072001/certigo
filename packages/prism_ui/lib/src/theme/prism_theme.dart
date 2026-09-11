import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/prism_radii.dart' show PrismRadii;
import '../tokens/prism_state.dart';
import '../tokens/prism_typography.dart';
import 'prism_color_scheme.dart';

/// Builds the Material [ThemeData] for Certigo from Prism tokens.
///
/// We lean on Material 3 for accessibility plumbing (touch targets, focus,
/// contrast) but override the surfaces, shapes and type so the result reads as
/// the bespoke "Prism" language rather than stock Material.
///
/// Le thème a **huit** formes, pas deux : `brightness` croisée avec les deux
/// réglages système `highContrast` et `reduceTransparency`. Elles sont toutes
/// construites par [resolve] depuis un unique [PrismColorScheme] re-dérivé, de
/// sorte qu'aucun `ThemeData` ne puisse tenir un rôle que le schéma ignore.
class PrismTheme {
  const PrismTheme._();

  /// Le thème d'une apparence et des réglages d'accessibilité.
  static ThemeData resolve({
    required Brightness brightness,
    bool highContrast = false,
    bool reduceTransparency = false,
    bool boldText = false,
  }) =>
      _build(
        PrismColorScheme.resolve(
          brightness: brightness,
          highContrast: highContrast,
          reduceTransparency: reduceTransparency,
        ),
        boldText: boldText,
      );

  static ThemeData light({
    bool highContrast = false,
    bool reduceTransparency = false,
    bool boldText = false,
  }) =>
      resolve(
        brightness: Brightness.light,
        highContrast: highContrast,
        reduceTransparency: reduceTransparency,
        boldText: boldText,
      );

  static ThemeData dark({
    bool highContrast = false,
    bool reduceTransparency = false,
    bool boldText = false,
  }) =>
      resolve(
        brightness: Brightness.dark,
        highContrast: highContrast,
        reduceTransparency: reduceTransparency,
        boldText: boldText,
      );

  static ThemeData _build(PrismColorScheme p, {bool boldText = false}) {
    final bool isDark = p.brightness == Brightness.dark;
    final TextTheme text = PrismTypography.build(
      p.textPrimary,
      p.textSecondary,
      boldText: boldText,
    );

    final ColorScheme scheme = ColorScheme(
      brightness: p.brightness,
      // `primary` here is paired with `onPrimary` white, so it must be the
      // FILL role — Material paints text on top of it.
      primary: p.primaryFill,
      onPrimary: p.onPrimary,
      secondary: p.primaryVivid,
      onSecondary: p.onPrimary,
      error: p.errorFill,
      onError: p.onPrimary,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceAlt,
      outline: p.border,
      outlineVariant: p.borderStrong,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      textTheme: text,
      splashFactory: InkRipple.splashFactory,
      // These are the measured state layers, not guesses. Before this change
      // both pressables forced `overlayColor: Colors.transparent`, so hover
      // never rendered anywhere in the app; and hover/highlight sat 1% of alpha
      // apart (1.07:1 vs 1.08:1), which is one state wearing two names.
      hoverColor: p.primaryVivid.withValues(alpha: PrismStateLayer.hover(p.brightness)),
      focusColor: p.primaryVivid.withValues(alpha: PrismStateLayer.focusHalo(p.brightness)),
      highlightColor: p.primaryVivid.withValues(alpha: PrismStateLayer.pressed(p.brightness)),
      splashColor: p.primaryVivid.withValues(alpha: PrismStateLayer.pressed(p.brightness)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
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
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size.square(48)),
          foregroundColor: WidgetStatePropertyAll<Color>(p.textPrimary),
          overlayColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
            if (states.contains(WidgetState.pressed)) {
              return p.primaryVivid.withValues(alpha: PrismStateLayer.pressed(p.brightness));
            }
            if (states.contains(WidgetState.hovered)) {
              return p.primaryVivid.withValues(alpha: PrismStateLayer.hover(p.brightness));
            }
            if (states.contains(WidgetState.focused)) {
              return p.primaryVivid.withValues(alpha: PrismStateLayer.focusHalo(p.brightness));
            }
            return const Color(0x00000000);
          }),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: PrismRadii.cardLg,
          side: BorderSide(color: p.border),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        side: BorderSide(color: p.border),
        labelStyle: text.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: PrismRadii.pillAll),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: PrismRadii.cardMd),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
        hintStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
        border: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.primaryOnSurface, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.errorOnSurface),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? p.surfaceAlt : p.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: isDark ? p.textPrimary : p.surface),
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
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: PrismRadii.cardXl),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? p.surfaceAlt : p.textPrimary,
          borderRadius: PrismRadii.cardSm,
        ),
        textStyle: text.labelMedium?.copyWith(color: isDark ? p.textPrimary : p.background),
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 2),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primaryOnSurface,
        selectionColor: p.primaryVivid.withValues(alpha: 0.28),
        selectionHandleColor: p.primaryOnSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primaryVivid,
        linearTrackColor: p.surfaceAlt,
        circularTrackColor: p.surfaceAlt,
      ),
    );
  }
}
