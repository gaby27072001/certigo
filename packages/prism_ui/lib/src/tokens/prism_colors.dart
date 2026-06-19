import 'package:flutter/widgets.dart';

/// Prism color tokens — the raw palette of the Microlingo design language.
///
/// These are *primitive* tokens. UI code should almost never reference them
/// directly; prefer the semantic roles exposed by [PrismColorScheme] via the
/// theme extension. Kept const and dependency-free so they can be reused by
/// tooling, tests and golden snapshots.
@immutable
class PrismColors {
  const PrismColors._();

  // ---- Brand -------------------------------------------------------------
  /// Primary "Prism Blue" — focus, trust, the spine of the brand.
  static const Color primary = Color(0xFF3B6AF0);
  static const Color primaryDark = Color(0xFF2B50C4);
  static const Color primarySoft = Color(0xFFE5ECFF);

  /// Ember — energy, streaks, "you're on fire" moments.
  static const Color ember = Color(0xFFFF7A45);
  static const Color emberSoft = Color(0xFFFFE6DB);

  /// XP gold — reward, mastery, celebration.
  static const Color xpGold = Color(0xFFFFC24B);
  static const Color xpGoldSoft = Color(0xFFFFF1D6);

  // ---- Semantic feedback -------------------------------------------------
  static const Color success = Color(0xFF1FB87A);
  static const Color successSoft = Color(0xFFD8F5EA);
  static const Color warning = Color(0xFFF5A524);
  static const Color warningSoft = Color(0xFFFDEFD3);
  static const Color error = Color(0xFFF0476A);
  static const Color errorSoft = Color(0xFFFCDDE4);
  static const Color info = Color(0xFF3BA0F0);
  static const Color infoSoft = Color(0xFFDDEFFC);

  // ---- Neutrals (light) --------------------------------------------------
  static const Color lightBg = Color(0xFFF8FAFD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFF3FA);
  static const Color lightTextPrimary = Color(0xFF0B1120);
  static const Color lightTextSecondary = Color(0xFF53607A);
  static const Color lightBorder = Color(0xFFE2E8F2);

  // ---- Neutrals (dark) ---------------------------------------------------
  static const Color darkBg = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF131A2A);
  static const Color darkSurfaceAlt = Color(0xFF1B2438);
  static const Color darkTextPrimary = Color(0xFFF5F8FF);
  static const Color darkTextSecondary = Color(0xFF9AA6BE);
  static const Color darkBorder = Color(0xFF273149);

  // ---- Glass (Liquid-Glass inspired translucent fills) -------------------
  static const Color glassLightFill = Color(0x66FFFFFF); // 40% white
  static const Color glassLightStroke = Color(0x4DFFFFFF); // 30% white
  static const Color glassDarkFill = Color(0x40131A2A); // 25% surface
  static const Color glassDarkStroke = Color(0x33FFFFFF); // 20% white

  // ---- Domain accents (per exam-domain color coding) ---------------------
  /// Stable, color-blind-aware accents used to tag exam domains and mastery
  /// rings. Ordered; content maps domain index -> accent deterministically.
  static const List<Color> domainAccents = <Color>[
    Color(0xFF3B6AF0), // blue
    Color(0xFF1FB87A), // green
    Color(0xFFFF7A45), // ember
    Color(0xFF8C5CF6), // violet
    Color(0xFF22B8CF), // teal
    Color(0xFFF0476A), // rose
  ];
}
