import 'package:flutter/material.dart';
import '../tokens/prism_colors.dart';
import '../tokens/prism_state.dart';

/// Semantic color roles for Certigo, exposed as a [ThemeExtension] so any
/// widget can read `Theme.of(context).extension<PrismColorScheme>()` (or the
/// `context.prism` helper) and stay correct in light *and* dark mode.
///
/// This is the layer UI code should depend on — never the raw [PrismColors].
///
/// ## Trois rôles, pas une couleur
///
/// A single colour cannot be a fill, a label and a wash at once; pretending it
/// can is what forces a palette to compromise until nothing is quite legible.
/// Every accent here therefore appears in several roles:
///
/// * **the bare name** ([primary], [success], …) — the accent as a
///   **foreground**: text, icon, divider, border. This is the default because
///   it is overwhelmingly the common case (measured: 108 foreground uses
///   against 6 solid fills). It therefore **adapts between themes** — ink on
///   light chrome, glow on dark — exactly as `systemBlue` differs between
///   Apple's appearances. Making it identical in both was a real regression:
///   six of seven accents fell to 2.6–3.1:1 on dark chrome.
/// * **fill** ([primaryFill], [successFill], …) — a solid block that carries
///   white text. Identical in light and dark, because a fill sits on top of
///   the chrome rather than inside it.
/// * **onSurface** ([primaryOnSurface], …) — the explicit foreground role.
///   Same value as the bare name; kept because naming the intent is worth more
///   than the keystrokes at a call site that cares.
/// * **soft** ([primarySoft], …) — a wash for tinting a whole region in the
///   accent's hue, which is how a track colours its own area.
///
/// The rule behind the rule: **the default must be safe, the exception must be
/// named.** A call site that writes `color: p.error` and thinks no further
/// should get a legible result on both appearances.
///
/// ## Quatre axes, huit combinaisons
///
/// Le schéma ne porte plus une seule dimension. À `brightness` s'ajoutent deux
/// réglages système d'accessibilité, [highContrast] et [reduceTransparency],
/// ce qui fait **huit** apparences livrées et non deux. Elles sont toutes
/// produites par [resolve], qui **re-dérive** les rôles depuis les deux bases
/// [light] et [dark] au lieu de figer huit tables de valeurs hexadécimales :
/// une table figée serait exactement la dérive que `prism_token_export` existe
/// pour empêcher.
///
/// Les deux bases restent la source exportée vers le natif. Ajouter un axe n'a
/// donc ajouté **aucun** jeton.
@immutable
class PrismColorScheme extends ThemeExtension<PrismColorScheme> {
  const PrismColorScheme({
    required this.brightness,
    this.highContrast = false,
    this.reduceTransparency = false,
    required this.primary,
    required this.primaryFill,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryVivid,
    required this.primaryOnSurface,
    required this.onPrimary,
    required this.ember,
    required this.emberFill,
    required this.emberOnSurface,
    required this.emberSoft,
    required this.xpGold,
    required this.xpGoldFill,
    required this.xpGoldOnSurface,
    required this.xpGoldSoft,
    required this.success,
    required this.successFill,
    required this.successOnSurface,
    required this.successSoft,
    required this.warning,
    required this.warningFill,
    required this.warningOnSurface,
    required this.warningSoft,
    required this.error,
    required this.errorFill,
    required this.errorOnSurface,
    required this.errorSoft,
    required this.info,
    required this.infoFill,
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
    required this.domainAccentsFill,
    required this.domainAccentsVivid,
    required this.domainAccentsOnSurface,
    required this.domainAccentsSoft,
  });

  final Brightness brightness;

  /// L'utilisateur a demandé **Increase Contrast** au système.
  ///
  /// Les couleurs système d'Apple s'y adaptent seules ; les couleurs
  /// personnalisées doivent fournir leurs variantes — et Certigo est
  /// entièrement en couleurs personnalisées. Voir [resolve].
  final bool highContrast;

  /// L'utilisateur a demandé **Reduce Transparency** au système.
  ///
  /// C'est une demande explicite de supprimer la translucidité, pas de
  /// l'atténuer : sous ce réglage [GlassSurface] cesse de poser un
  /// `BackdropFilter` et [glassFill] devient opaque.
  final bool reduceTransparency;

  /// Brand accent as a **foreground** — text, icon, border. Adapts per theme.
  final Color primary;

  /// Brand accent as a **solid fill** that carries [onPrimary] text.
  final Color primaryFill;

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
  final Color emberFill;
  final Color emberOnSurface;
  final Color emberSoft;
  final Color xpGold;
  final Color xpGoldFill;
  final Color xpGoldOnSurface;
  final Color xpGoldSoft;
  final Color success;
  final Color successFill;
  final Color successOnSurface;
  final Color successSoft;
  final Color warning;
  final Color warningFill;
  final Color warningOnSurface;
  final Color warningSoft;
  final Color error;
  final Color errorFill;
  final Color errorOnSurface;
  final Color errorSoft;
  final Color info;
  final Color infoFill;
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

  /// Solid-fill role per exam domain: carries [onPrimary] text. Identical in
  /// both themes, because a fill sits on top of the chrome. Use this whenever
  /// a domain accent becomes a button tone or any block that text sits on.
  final List<Color> domainAccentsFill;

  /// Vivid role per exam domain — rings, progress, fills.
  final List<Color> domainAccentsVivid;

  /// Per-domain accent as text on the current chrome.
  final List<Color> domainAccentsOnSurface;

  /// Per-domain wash, for a track colouring its own region.
  final List<Color> domainAccentsSoft;

  /// Deterministic accent for an exam domain by index.
  Color accentFor(int domainIndex) => domainAccents[domainIndex % domainAccents.length];

  /// Solid-fill accent for an exam domain — carries [onPrimary] text. Use this
  /// for a button tone or any block that text sits on.
  Color accentFillFor(int domainIndex) => domainAccentsFill[domainIndex % domainAccentsFill.length];

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
    // Light chrome: the ink role is both the foreground and the fill, because
    // a colour dark enough to read on white is also dark enough to carry white
    // text.
    primary: PrismColors.primary,
    primaryFill: PrismColors.primary,
    primaryDark: PrismColors.primaryDark,
    primarySoft: PrismColors.primarySoft,
    primaryVivid: PrismColors.primaryVivid,
    primaryOnSurface: PrismColors.primary,
    onPrimary: Color(0xFFFFFFFF),
    ember: PrismColors.ember,
    emberFill: PrismColors.ember,
    emberOnSurface: PrismColors.ember,
    emberSoft: PrismColors.emberSoft,
    xpGold: PrismColors.xpGold,
    xpGoldFill: PrismColors.xpGold,
    xpGoldOnSurface: PrismColors.xpGold,
    xpGoldSoft: PrismColors.xpGoldSoft,
    success: PrismColors.success,
    successFill: PrismColors.success,
    successOnSurface: PrismColors.success,
    successSoft: PrismColors.successSoft,
    warning: PrismColors.warning,
    warningFill: PrismColors.warning,
    warningOnSurface: PrismColors.warning,
    warningSoft: PrismColors.warningSoft,
    error: PrismColors.error,
    errorFill: PrismColors.error,
    errorOnSurface: PrismColors.error,
    errorSoft: PrismColors.errorSoft,
    info: PrismColors.info,
    infoFill: PrismColors.info,
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
    domainAccentsFill: PrismColors.spectrumInk,
    domainAccentsVivid: PrismColors.spectrumVivid,
    domainAccentsOnSurface: PrismColors.spectrumInk,
    domainAccentsSoft: PrismColors.spectrumSoftLight,
  );

  static const PrismColorScheme dark = PrismColorScheme(
    brightness: Brightness.dark,
    // Dark chrome: the bare name resolves to the **glow** role, because on dark
    // chrome the overwhelmingly common use of an accent is as a foreground.
    // The fill stays on ink, where white text still reads.
    primary: PrismColors.primaryGlow,
    primaryFill: PrismColors.primary,
    primaryDark: PrismColors.primaryDark,
    primarySoft: PrismColors.primarySoftDark,
    primaryVivid: PrismColors.primaryVivid,
    primaryOnSurface: PrismColors.primaryGlow,
    onPrimary: Color(0xFFFFFFFF),
    ember: PrismColors.emberGlow,
    emberFill: PrismColors.ember,
    emberOnSurface: PrismColors.emberGlow,
    emberSoft: PrismColors.errorSoftDark,
    xpGold: PrismColors.xpGoldGlow,
    xpGoldFill: PrismColors.xpGold,
    xpGoldOnSurface: PrismColors.xpGoldGlow,
    xpGoldSoft: PrismColors.warningSoftDark,
    success: PrismColors.successGlow,
    successFill: PrismColors.success,
    successOnSurface: PrismColors.successGlow,
    successSoft: PrismColors.successSoftDark,
    warning: PrismColors.warningGlow,
    warningFill: PrismColors.warning,
    warningOnSurface: PrismColors.warningGlow,
    warningSoft: PrismColors.warningSoftDark,
    error: PrismColors.errorGlow,
    errorFill: PrismColors.error,
    errorOnSurface: PrismColors.errorGlow,
    errorSoft: PrismColors.errorSoftDark,
    info: PrismColors.infoGlow,
    infoFill: PrismColors.info,
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
    domainAccents: PrismColors.spectrumGlow,
    domainAccentsFill: PrismColors.spectrumInk,
    domainAccentsVivid: PrismColors.spectrumVivid,
    domainAccentsOnSurface: PrismColors.spectrumGlow,
    domainAccentsSoft: PrismColors.spectrumSoftDark,
  );

  // ---- Les deux axes d'accessibilité ------------------------------------
  //
  // Déplacement appliqué aux rôles d'encre — premiers plans et aplats.
  //
  // Mesuré sur cet arbre (pire rôle, tous accents et domaines confondus) :
  //
  //   sur la carte    clair 5.94 -> 8.79   sombre 5.52 -> 7.18
  //   sur le verre    clair 5.76 -> 8.51   sombre 4.99 -> 6.48
  //   aplat sous blanc      5.94 -> 8.79 (identique dans les deux thèmes)
  //
  // 0.25 est le plus petit déplacement qui porte le pire premier plan au-delà
  // de 7.0 (AAA) sur la carte et la page **dans les deux thèmes** — le sombre
  // est le cas contraignant, à 7.18.
  static const double _inkShift = 0.25;

  // Déplacement appliqué aux arêtes. Plus grand que celui de l'encre parce
  // qu'une arête part de beaucoup plus bas : 1.70:1 contre 5.94:1. Mesuré, le
  // pire trait passe de 1.65 à 3.53, soit au-dessus du seuil non textuel de
  // 3.0 ; à 0.25 il plafonnait à 2.91 et échouait.
  static const double _edgeShift = 0.34;

  static const Color _black = Color(0xFF000000);
  static const Color _white = Color(0xFFFFFFFF);

  /// Éloigne une couleur de son chrome : vers le noir en clair, vers le blanc
  /// en sombre. C'est la même loi directionnelle que l'arête du verre — ce qui
  /// sépare en clair rapproche en sombre.
  static Color _awayFromChrome(Color c, bool isDark, double t) =>
      Color.lerp(c, isDark ? _white : _black, t)!;

  /// Le schéma résolu pour une apparence et les deux réglages d'accessibilité.
  ///
  /// **Ce qui bouge, et pourquoi seulement cela.** Les plans
  /// ([background], [surface], [surfaceAlt]) et les lavis (`*Soft`) ne bougent
  /// pas. Les déplacer aurait été le piège que §10 de `DESIGN.md` documente :
  /// en clair, pousser le lavis vers le blanc l'aurait rendu identique à
  /// [surface] (`#FFFFFF`), remplaçant un défaut de contraste par une perte de
  /// hiérarchie. Les plans tiennent déjà leur plancher de 1.12:1 ; ils n'ont
  /// rien à gagner et une distinction à perdre.
  ///
  /// [litEdge] n'est **jamais** transformé, pour la même raison. En clair il
  /// vaut `0x00FFFFFF`, entièrement transparent par décision mesurée ; le
  /// déplacer vers le noir lui donnerait un alpha et ferait apparaître un
  /// liseré **sombre** en haut du verre clair, c'est-à-dire exactement le
  /// défaut que §4 a supprimé.
  static PrismColorScheme resolve({
    required Brightness brightness,
    bool highContrast = false,
    bool reduceTransparency = false,
  }) {
    final PrismColorScheme base = brightness == Brightness.dark ? dark : light;
    if (!highContrast && !reduceTransparency) return base;
    return base._withAxes(
      highContrast: highContrast,
      reduceTransparency: reduceTransparency,
    );
  }

  PrismColorScheme _withAxes({required bool highContrast, required bool reduceTransparency}) {
    final bool isDark = brightness == Brightness.dark;

    /// Un premier plan s'éloigne du chrome qui le porte.
    Color ink(Color c) => highContrast ? _awayFromChrome(c, isDark, _inkShift) : c;

    /// Un aplat porte du texte blanc : il s'assombrit dans les deux thèmes,
    /// jamais l'inverse. C'est la distinction que `prism_fill_role_guard_test`
    /// garde, transposée au nouvel axe.
    Color fill(Color c) => highContrast ? Color.lerp(c, _black, _inkShift)! : c;

    /// Une arête se renforce sous Increase Contrast.
    Color edge(Color c) => highContrast ? _awayFromChrome(c, isDark, _edgeShift) : c;

    /// L'arête **du verre** se renforce aussi sous Reduce Transparency : le
    /// flou était un séparateur, il disparaît, l'arête reprend la charge. La
    /// portée s'arrête là — renforcer au passage les bordures de toutes les
    /// cartes serait un effet de bord que le réglage n'a pas demandé.
    Color glassEdge(Color c) =>
        highContrast || reduceTransparency ? _awayFromChrome(c, isDark, _edgeShift) : c;

    List<Color> inks(List<Color> cs) => <Color>[for (final Color c in cs) ink(c)];
    List<Color> fills(List<Color> cs) => <Color>[for (final Color c in cs) fill(c)];

    return copyWith(
      highContrast: highContrast,
      reduceTransparency: reduceTransparency,
      primary: ink(primary),
      primaryFill: fill(primaryFill),
      primaryDark: fill(primaryDark),
      primaryVivid: ink(primaryVivid),
      primaryOnSurface: ink(primaryOnSurface),
      ember: ink(ember),
      emberFill: fill(emberFill),
      emberOnSurface: ink(emberOnSurface),
      xpGold: ink(xpGold),
      xpGoldFill: fill(xpGoldFill),
      xpGoldOnSurface: ink(xpGoldOnSurface),
      success: ink(success),
      successFill: fill(successFill),
      successOnSurface: ink(successOnSurface),
      warning: ink(warning),
      warningFill: fill(warningFill),
      warningOnSurface: ink(warningOnSurface),
      error: ink(error),
      errorFill: fill(errorFill),
      errorOnSurface: ink(errorOnSurface),
      info: ink(info),
      infoFill: fill(infoFill),
      infoOnSurface: ink(infoOnSurface),
      textPrimary: ink(textPrimary),
      textSecondary: ink(textSecondary),
      textDisabled: ink(textDisabled),
      border: edge(border),
      borderStrong: edge(borderStrong),
      // Le verre cesse d'être du verre : on l'aplatit sur la page, ce qui rend
      // exactement le pixel que l'utilisateur voit déjà quand la barre flotte
      // au-dessus du fond — #FBFBFD en clair, #232736 en sombre — mais opaque,
      // donc sans `BackdropFilter` derrière.
      glassFill: reduceTransparency ? Color.alphaBlend(glassFill, background) : glassFill,
      glassStroke: glassEdge(glassStroke),
      domainAccents: inks(domainAccents),
      domainAccentsFill: fills(domainAccentsFill),
      domainAccentsVivid: inks(domainAccentsVivid),
      domainAccentsOnSurface: inks(domainAccentsOnSurface),
    );
  }

  @override
  PrismColorScheme copyWith({
    Brightness? brightness,
    bool? highContrast,
    bool? reduceTransparency,
    Color? primary,
    Color? primaryFill,
    Color? primaryDark,
    Color? primarySoft,
    Color? primaryVivid,
    Color? primaryOnSurface,
    Color? onPrimary,
    Color? ember,
    Color? emberFill,
    Color? emberOnSurface,
    Color? emberSoft,
    Color? xpGold,
    Color? xpGoldFill,
    Color? xpGoldOnSurface,
    Color? xpGoldSoft,
    Color? success,
    Color? successFill,
    Color? successOnSurface,
    Color? successSoft,
    Color? warning,
    Color? warningFill,
    Color? warningOnSurface,
    Color? warningSoft,
    Color? error,
    Color? errorFill,
    Color? errorOnSurface,
    Color? errorSoft,
    Color? info,
    Color? infoFill,
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
    List<Color>? domainAccentsFill,
    List<Color>? domainAccentsVivid,
    List<Color>? domainAccentsOnSurface,
    List<Color>? domainAccentsSoft,
  }) {
    return PrismColorScheme(
      brightness: brightness ?? this.brightness,
      highContrast: highContrast ?? this.highContrast,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      primary: primary ?? this.primary,
      primaryFill: primaryFill ?? this.primaryFill,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryVivid: primaryVivid ?? this.primaryVivid,
      primaryOnSurface: primaryOnSurface ?? this.primaryOnSurface,
      onPrimary: onPrimary ?? this.onPrimary,
      ember: ember ?? this.ember,
      emberFill: emberFill ?? this.emberFill,
      emberOnSurface: emberOnSurface ?? this.emberOnSurface,
      emberSoft: emberSoft ?? this.emberSoft,
      xpGold: xpGold ?? this.xpGold,
      xpGoldFill: xpGoldFill ?? this.xpGoldFill,
      xpGoldOnSurface: xpGoldOnSurface ?? this.xpGoldOnSurface,
      xpGoldSoft: xpGoldSoft ?? this.xpGoldSoft,
      success: success ?? this.success,
      successFill: successFill ?? this.successFill,
      successOnSurface: successOnSurface ?? this.successOnSurface,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningFill: warningFill ?? this.warningFill,
      warningOnSurface: warningOnSurface ?? this.warningOnSurface,
      warningSoft: warningSoft ?? this.warningSoft,
      error: error ?? this.error,
      errorFill: errorFill ?? this.errorFill,
      errorOnSurface: errorOnSurface ?? this.errorOnSurface,
      errorSoft: errorSoft ?? this.errorSoft,
      info: info ?? this.info,
      infoFill: infoFill ?? this.infoFill,
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
      domainAccentsFill: domainAccentsFill ?? this.domainAccentsFill,
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
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      reduceTransparency: t < 0.5 ? reduceTransparency : other.reduceTransparency,
      primary: c(primary, other.primary),
      primaryFill: c(primaryFill, other.primaryFill),
      primaryDark: c(primaryDark, other.primaryDark),
      primarySoft: c(primarySoft, other.primarySoft),
      primaryVivid: c(primaryVivid, other.primaryVivid),
      primaryOnSurface: c(primaryOnSurface, other.primaryOnSurface),
      onPrimary: c(onPrimary, other.onPrimary),
      ember: c(ember, other.ember),
      emberFill: c(emberFill, other.emberFill),
      emberOnSurface: c(emberOnSurface, other.emberOnSurface),
      emberSoft: c(emberSoft, other.emberSoft),
      xpGold: c(xpGold, other.xpGold),
      xpGoldFill: c(xpGoldFill, other.xpGoldFill),
      xpGoldOnSurface: c(xpGoldOnSurface, other.xpGoldOnSurface),
      xpGoldSoft: c(xpGoldSoft, other.xpGoldSoft),
      success: c(success, other.success),
      successFill: c(successFill, other.successFill),
      successOnSurface: c(successOnSurface, other.successOnSurface),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningFill: c(warningFill, other.warningFill),
      warningOnSurface: c(warningOnSurface, other.warningOnSurface),
      warningSoft: c(warningSoft, other.warningSoft),
      error: c(error, other.error),
      errorFill: c(errorFill, other.errorFill),
      errorOnSurface: c(errorOnSurface, other.errorOnSurface),
      errorSoft: c(errorSoft, other.errorSoft),
      info: c(info, other.info),
      infoFill: c(infoFill, other.infoFill),
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
      domainAccentsFill: t < 0.5 ? domainAccentsFill : other.domainAccentsFill,
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
