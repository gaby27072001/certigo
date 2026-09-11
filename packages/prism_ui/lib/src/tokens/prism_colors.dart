import 'package:flutter/widgets.dart';

/// Prism color tokens — the raw palette of the Certigo design language.
///
/// These are *primitive* tokens. UI code should almost never reference them
/// directly; prefer the semantic roles exposed by `PrismColorScheme` via the
/// theme extension. Kept const and dependency-free so they can be reused by
/// tooling, tests and golden snapshots.
///
/// ## The refracted spectrum
///
/// The design system is called Prism, and a prism does one thing: it takes a
/// single light and separates it into a coherent spectrum. That is the whole
/// color model. Every certification track owns **one refracted band** of the
/// same light, so the app is colorful *and* ordered rather than colorful *or*
/// ordered.
///
/// Bands are derived in OKLCH, not picked by eye, under one measured law:
///
/// * **Lightness is constant across the spectrum.** This is what organizes it.
///   At a fixed L, contrast against a given background stays within a narrow
///   band (measured: 3.4–4.2 against white at L=0.62) no matter the hue, even
///   as chroma varies fourfold. Constant L therefore buys uniform legibility
///   and equal visual weight — no band shouts over its neighbours.
/// * **Chroma is pushed to each hue's own sRGB ceiling.** Literal constant
///   chroma was measured and rejected: cyan tops out at C≈0.11 while magenta
///   reaches C≈0.28, so one shared chroma would drag the whole spectrum down
///   to the cyan ceiling and drain exactly the joy the palette exists for.
///
/// Each band ships in three lightness roles, because one color cannot do every
/// job:
///
/// * **ink** (L≈0.515) — text and solid fills. Body-text safe on the light
///   canvas, and safe *under* white body text when used as a fill.
/// * **vivid** (L≈0.62) — progress, rings, chips, glows, large type.
///   Deliberately not a body-text color.
/// * **glow** (L≈0.68) — text and icons on dark chrome.
///
/// Every pairing here was verified numerically before it was written down, and
/// the floors are re-derived in `prism_colors_test.dart` so they cannot rot.
@immutable
class PrismColors {
  const PrismColors._();

  // ---- Brand -------------------------------------------------------------
  /// Primary — the violet band of the spectrum, and the app's own light.
  ///
  /// Certigo previously signed itself with Microsoft's Fluent blue so the app
  /// would "instantly read as Azure". That made the product read as one
  /// vendor's console rather than as itself, and it is the single change most
  /// responsible for the interface feeling corporate. The Azure blue is not
  /// gone — it survives as [azureTrack], where a vendor color belongs.
  static const Color primary = Color(0xFF3B35F2);

  /// Pressed / gradient-bottom variant.
  static const Color primaryDark = Color(0xFF2B1AC4);

  /// Soft tint for fills, selection and chips.
  static const Color primarySoft = Color(0xFFE9ECF8);

  /// Brand wash on dark chrome — the violet band's soft role.
  static const Color primarySoftDark = Color(0xFF192061);

  /// Vivid brand fill (rings, progress, glow) — not a body-text color.
  static const Color primaryVivid = Color(0xFF6178F6);

  /// Brand tone for dark chrome (text and icons).
  static const Color primaryGlow = Color(0xFF8097F8);

  /// Ember — energy, streaks, "you're on fire" moments.
  static const Color ember = Color(0xFFB02013);
  static const Color emberVivid = Color(0xFFF12F1E);
  static const Color emberGlow = Color(0xFFF86C59);
  static const Color emberSoft = Color(0xFFF8E9E6);

  /// XP gold — reward, mastery, celebration.
  static const Color xpGold = Color(0xFF924A13);
  static const Color xpGoldVivid = Color(0xFFC9681F);
  static const Color xpGoldGlow = Color(0xFFEC7B26);
  static const Color xpGoldSoft = Color(0xFFF8EAE2);

  /// Podium medals — silver and bronze.
  ///
  /// Gold is not repeated here: the app already has one gold, [xpGold], and a
  /// second one beside it would read as a mistake rather than a distinction.
  ///
  /// These exist as primitives because a podium is ranked, and rank must stay
  /// legible. The literal they replace, `Color(0xFFB8C2D9)`, was written inline
  /// in the leaderboard with no light counterpart: it scored **1.79:1** on the
  /// white card, so second place was very nearly invisible in the light theme
  /// while being perfect in the dark one.
  static const Color medalSilver = Color(0xFF566076);
  static const Color medalSilverGlow = Color(0xFFB8C2D9);
  static const Color medalBronze = Color(0xFF7E4425);
  static const Color medalBronzeGlow = Color(0xFFD79367);

  // ---- Semantic feedback -------------------------------------------------
  // Same constant-lightness law, so status color never outshouts track color.
  static const Color success = Color(0xFF177331);
  static const Color successVivid = Color(0xFF24A047);
  static const Color successGlow = Color(0xFF2DBC55);
  static const Color successSoft = Color(0xFFD4F8D8);
  static const Color successSoftDark = Color(0xFF17311B);

  static const Color warning = Color(0xFF805713);
  static const Color warningVivid = Color(0xFFB07A1F);
  static const Color warningGlow = Color(0xFFCF9026);
  static const Color warningSoft = Color(0xFFF8EBDA);
  static const Color warningSoftDark = Color(0xFF352714);

  static const Color error = Color(0xFFB01B2D);
  static const Color errorVivid = Color(0xFFF12941);
  static const Color errorGlow = Color(0xFFF8696B);
  static const Color errorSoft = Color(0xFFF8E9E8);
  static const Color errorSoftDark = Color(0xFF471919);

  static const Color info = Color(0xFF1562AA);
  static const Color infoVivid = Color(0xFF2188E8);
  static const Color infoGlow = Color(0xFF52A2F8);
  static const Color infoSoft = Color(0xFFE5EEF8);
  static const Color infoSoftDark = Color(0xFF152B44);

  // ---- Neutrals (light) --------------------------------------------------
  // The canvas is a tinted grey and cards are white, so a card is a *lighter*
  // plane floating above its background. The previous scheme had it the other
  // way round — a white card on a near-white canvas measured 1.019:1, which is
  // the whole of "the colours blend together".
  static const Color lightBg = Color(0xFFECEEF5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFDDE0EC);
  static const Color lightTextPrimary = Color(0xFF161A29);
  static const Color lightTextSecondary = Color(0xFF555A6B);
  static const Color lightTextDisabled = Color(0xFF858894);
  static const Color lightBorder = Color(0xFFC2C6D4);

  /// Firmer edge for controls that must read as tappable at a glance.
  static const Color lightBorderStrong = Color(0xFFA3A9BC);

  // ---- Neutrals (dark) ---------------------------------------------------
  static const Color darkBg = Color(0xFF0D1019);
  static const Color darkSurface = Color(0xFF1C1F2B);
  static const Color darkSurfaceAlt = Color(0xFF292E3D);
  static const Color darkTextPrimary = Color(0xFFF5F7FC);
  static const Color darkTextSecondary = Color(0xFFADB1C0);
  static const Color darkTextDisabled = Color(0xFF767A87);
  static const Color darkBorder = Color(0xFF414759);
  static const Color darkBorderStrong = Color(0xFF5A6076);

  // ---- Glass -------------------------------------------------------------
  // Liquid Glass is a *material*, and a material is legible only where its
  // edge is. The previous stroke was white-on-white: measured 1.008:1 against
  // its own fill, where 1.000 is literally identical. That one value is the
  // whole of "the buttons are badly outlined".
  //
  // The fix is directional, not cosmetic: in light mode the edge is **darker**
  // than the fill, in dark mode **lighter**. A white lit edge over a light
  // fill measured 1.00 and is therefore never used — the lit edge is a
  // dark-chrome mechanic, and light mode leads with shadow instead.
  static const Color glassLightFill = Color(0xC7FFFFFF);
  static const Color glassLightStroke = Color(0xFFC2C6D4);
  static const Color glassDarkFill = Color(0xBF2A2F40);
  static const Color glassDarkStroke = Color(0x42FFFFFF);

  /// Directional top highlight — the lit edge of the material. Dark chrome
  /// only; see the note above.
  static const Color glassDarkLitEdge = Color(0x29FFFFFF);

  // ---- The refracted spectrum -------------------------------------------
  /// Text / solid-fill role (L≈0.515). Body-text safe on the light canvas.
  static const List<Color> spectrumInk = <Color>[
    Color(0xFF3B35F2), // violet — the brand band
    Color(0xFF901BAE), // magenta
    Color(0xFFA91A66), // rose
    Color(0xFF924A13), // amber
    Color(0xFF177331), // green
    Color(0xFF176C7A), // cyan
  ];

  /// Vivid fill role (L≈0.62). Rings, progress, chips, glows, large type.
  static const List<Color> spectrumVivid = <Color>[
    Color(0xFF6178F6),
    Color(0xFFC629EE),
    Color(0xFFE7278D),
    Color(0xFFC9681F),
    Color(0xFF24A047),
    Color(0xFF2496A9),
  ];

  /// Dark-chrome role (L≈0.68). Text and icons on dark surfaces.
  static const List<Color> spectrumGlow = <Color>[
    Color(0xFF8097F8),
    Color(0xFFD764F8),
    Color(0xFFF95DA5),
    Color(0xFFEC7B26),
    Color(0xFF2DBC55),
    Color(0xFF2CB0C7),
  ];

  /// Whisper tint of each band, for light-mode region fills.
  static const List<Color> spectrumSoftLight = <Color>[
    Color(0xFFE9ECF8),
    Color(0xFFF4E8F8),
    Color(0xFFF8E8ED),
    Color(0xFFF8EAE2),
    Color(0xFFD4F8D8),
    Color(0xFFD9F2F8),
  ];

  /// Whisper tint of each band, for dark-mode region fills.
  static const List<Color> spectrumSoftDark = <Color>[
    Color(0xFF192061),
    Color(0xFF3B1945),
    Color(0xFF45182C),
    Color(0xFF3C2314),
    Color(0xFF17311B),
    Color(0xFF162E33),
  ];

  // ---- Vendor tints ------------------------------------------------------
  /// Microsoft's Fluent blue. Kept deliberately: it is the right color for the
  /// Azure *track*, and the wrong color for the Certigo *brand*.
  static const Color azureTrack = Color(0xFF0078D4);

  // ---- Domain accents (per exam-domain color coding) ---------------------
  /// Stable, color-blind-aware accents used to tag exam domains and mastery
  /// rings. Ordered; content maps domain index -> accent deterministically.
  /// These are the ink role, so a domain label stays body-text legible.
  static const List<Color> domainAccents = spectrumInk;
}
