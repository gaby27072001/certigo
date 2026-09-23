import 'package:flutter/material.dart';
import '../feedback/prism_haptics.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_elevation.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_spacing.dart';
import '../tokens/prism_state.dart';
import 'prism_pressable.dart';

/// Height of a [PrismButton]'s face at every text size where its label fits one
/// line. It is a floor: a label that needs more lines grows the face instead of
/// being truncated.
const double kPrismButtonFaceHeight = 54;

/// Button hierarchy for Certigo.
///
/// * [PrismButtonVariant.primary] — the single most important action on a
///   screen (Continue, Start lesson, Submit). Solid brand gradient + glow.
/// * [PrismButtonVariant.secondary] — supporting actions. Glass/tonal.
/// * [PrismButtonVariant.ghost] — low-emphasis / tertiary. Text-like.
///
/// Provides press scale and a built-in [loading] state so call sites never have
/// to reimplement button busy logic.
///
/// **Un bouton ne vibre pas par défaut.** [haptic] vaut [PrismHaptic.none] et
/// doit être demandé explicitement — voir le champ pour la mesure qui a conduit
/// à ce défaut.
enum PrismButtonVariant { primary, secondary, ghost }

class PrismButton extends StatefulWidget {
  const PrismButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PrismButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.tone,
    this.haptic = PrismHaptic.none,
  });

  const PrismButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.tone,
    this.haptic = PrismHaptic.none,
  }) : variant = PrismButtonVariant.secondary;

  const PrismButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.tone,
    this.haptic = PrismHaptic.none,
  }) : variant = PrismButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final PrismButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  /// Optional accent override so a CTA can adopt a contextual hue (domain
  /// accent, success, ember…) while keeping the same strong, rounded shape.
  final Color? tone;

  /// Le retour haptique de ce bouton — **[PrismHaptic.none] par défaut**.
  ///
  /// Mesuré sur `main` : ce champ n'existait pas et `_handleTap` appelait
  /// `HapticFeedback.lightImpact()` sans condition. `PrismButton` étant le
  /// bouton de toute l'application, **les 38 sites d'appel vibraient**, dont
  /// « Précédent », « Suivant » et « Refaire un examen ».
  ///
  /// Le défaut est sûr ; l'exception se nomme au site d'appel (DESIGN.md §10,
  /// règle 8). Mesuré à la reprise : **un seul** site la mérite — « Soumettre »
  /// de l'examen blanc. Les deux autres candidats évidents, valider une
  /// question et terminer une leçon, vibrent **déjà** par
  /// `HapticLessonFeedback` (`lesson_controller.dart:244/288/351`,
  /// `quiz_controller.dart:200`) : leur en donner un ici ferait **deux
  /// vibrations pour un seul geste**.
  final PrismHaptic haptic;

  @override
  State<PrismButton> createState() => _PrismButtonState();
}

class _PrismButtonState extends State<PrismButton> {
  bool _down = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handleTap() {
    PrismHaptics.play(widget.haptic);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Duration state = PrismMotion.resolve(context, PrismMotion.state);
    final bool depth = widget.variant != PrismButtonVariant.ghost;
    final double lip = depth ? 4 : 0;
    final double sink = depth && _down ? lip : 0;
    final TextStyle labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge!.copyWith(color: _foreground(p), fontWeight: FontWeight.w700);

    final Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(_foreground(p)),
            ),
          )
        else ...<Widget>[
          if (widget.icon != null) ...<Widget>[
            Icon(widget.icon, size: 20, color: _foreground(p)),
            const SizedBox(width: 8),
          ],
          Flexible(
            // Wraps rather than ellipsizes: a label cut to « Réparer ma… » names no
            // action at all. At 1× every label fits one line, so nothing moves.
            child: Text(widget.label, style: labelStyle, textAlign: TextAlign.center),
          ),
        ],
      ],
    );

    return Semantics(
      // A button is its own VoiceOver element. Without a container, its label and
      // tap action merge into the nearest boundary — measured: inside a list
      // item, the whole card (title, body, facts and the button) was announced
      // as one single button. Flutter's Material buttons set this for the same
      // reason.
      container: true,
      button: true,
      enabled: _enabled,
      liveRegion: widget.loading,
      label: widget.loading ? '${widget.label}, chargement' : widget.label,
      onTap: _enabled ? _handleTap : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: PrismRadii.buttonAll,
          // Prism paints its own measured state layers; Material's ripple is
          // suppressed rather than the state system being switched off.
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          onHover: (bool value) {
            if (_hovered != value) setState(() => _hovered = value);
          },
          onFocusChange: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          onHighlightChanged: _enabled
              ? (bool value) {
                  if (_down != value) setState(() => _down = value);
                }
              : null,
          onTap: _enabled ? _handleTap : null,
          child: ExcludeSemantics(
            child: Padding(
              // Room for the focus ring to sit outside the control.
              padding: const EdgeInsets.all(PrismFocusRing.inset),
              child: Padding(
                // Room for the lip, which sits under the face.
                padding: EdgeInsets.only(bottom: lip),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    if (depth)
                      Positioned(
                        top: lip,
                        bottom: -lip,
                        left: 0,
                        right: 0,
                        child: DecoratedBox(decoration: _baseDecoration(p)),
                      ),
                    // The face sizes the button, and its height is a floor, not a
                    // fixed value. Measured at Dynamic Type 2× on a 390 pt screen:
                    // with a fixed 54 pt face, « Réparer ma série » was cut to fit
                    // 233 px. A label that no longer fits one line now wraps and the
                    // face grows. At 1× — and at 2× for one line — it stays 54 pt.
                    AnimatedContainer(
                      duration: state,
                      curve: PrismMotion.continuous,
                      transform: Matrix4.translationValues(0, sink, 0),
                      child: AnimatedScale(
                        scale: _down ? 0.995 : 1.0,
                        duration: state,
                        curve: PrismMotion.continuous,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: kPrismButtonFaceHeight),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: PrismSpacing.xs,
                          ),
                          decoration: _topDecoration(p),
                          // Not `alignment:` — an Align fills any bounded height,
                          // so under a Center or in a dialog the face would take
                          // the whole screen. heightFactor 1 hugs the label; the
                          // floor above supplies the 54 pt.
                          child: Center(heightFactor: 1, child: content),
                        ),
                      ),
                    ),
                    if (_focused && _enabled)
                      Positioned(
                        left: -PrismFocusRing.inset,
                        right: -PrismFocusRing.inset,
                        top: -PrismFocusRing.inset,
                        // The ring still surrounds the lip, which now lies outside
                        // the stack's own box.
                        bottom: -PrismFocusRing.inset - lip,
                        child: IgnorePointer(
                          child: PrismFocusIndicator(
                            borderRadius: PrismRadii.buttonAll,
                            ringColor: p.focusRing,
                            gapColor: p.surface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _foreground(PrismColorScheme p) {
    // Disabled is a colour, not a blanket fade. Fading the whole control drove
    // the label to 1.48:1 — unreadable, and indistinguishable from a rendering
    // fault. `textDisabled` on the disabled `surface` fill measures 3.53:1 in
    // light and 3.83:1 in dark: clearly inert, still legible.
    if (!_enabled) return p.textDisabled;
    return switch (widget.variant) {
      PrismButtonVariant.primary => p.onPrimary,
      // A ghost button is still a control. Rendering it in `textSecondary`
      // made it read as ordinary prose, which is why "J'ai déjà un compte"
      // did not look tappable; the tint is what says "this is interactive".
      PrismButtonVariant.secondary => widget.tone ?? p.primaryOnSurface,
      PrismButtonVariant.ghost => widget.tone ?? p.primaryOnSurface,
    };
  }

  /// The measured state layer for this button, applied over its own fill.
  Color _stateBlend(PrismColorScheme p, Color base) {
    if (!_enabled) return base;
    if (_down) {
      return Color.alphaBlend(
        p.textPrimary.withValues(alpha: PrismStateLayer.pressed(p.brightness) * 0.5),
        base,
      );
    }
    if (_hovered) {
      return Color.alphaBlend(
        p.onPrimary.withValues(alpha: PrismStateLayer.hover(p.brightness)),
        base,
      );
    }
    return base;
  }

  BoxDecoration _topDecoration(PrismColorScheme p) {
    // A button's tone paints a solid block that carries [onPrimary] text, so
    // it takes the FILL role, not the adaptive foreground one.
    final Color tone = widget.tone ?? p.primaryFill;

    // Disabled is a flat, inert plane with a real edge, not a ghost of the
    // enabled control. `surface` is used rather than `surfaceAlt` because the
    // disabled label only clears 3:1 against it (3.53 light / 3.83 dark).
    if (!_enabled) {
      final bool ghost = widget.variant == PrismButtonVariant.ghost;
      return BoxDecoration(
        borderRadius: PrismRadii.buttonAll,
        color: ghost ? null : p.surface,
        border: ghost ? null : Border.all(color: p.border, width: 1.5),
      );
    }

    switch (widget.variant) {
      case PrismButtonVariant.primary:
        final Color toneDark =
            widget.tone == null ? p.primaryDark : Color.alphaBlend(const Color(0x29000000), tone);
        return BoxDecoration(
          borderRadius: PrismRadii.buttonAll,
          gradient: LinearGradient(
            colors: <Color>[_stateBlend(p, tone), _stateBlend(p, toneDark)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: _down ? const <BoxShadow>[] : PrismElevation.toned(p.brightness, tone),
        );
      case PrismButtonVariant.secondary:
        final Color fill = Color.alphaBlend(
          tone.withValues(alpha: p.brightness == Brightness.dark ? 0.22 : 0.13),
          p.surface,
        );
        return BoxDecoration(
          borderRadius: PrismRadii.buttonAll,
          color: _hovered ? p.hoverOn(fill, tint: tone) : fill,
          // A secondary button has no fill to announce itself with, so it takes
          // the firm edge. The previous 0.30-alpha tint measured 1.46:1 against
          // its own fill and effectively vanished.
          border: Border.all(
            color: Color.alphaBlend(tone.withValues(alpha: 0.55), p.borderStrong),
            width: 1.5,
          ),
        );
      case PrismButtonVariant.ghost:
        return BoxDecoration(
          borderRadius: PrismRadii.buttonAll,
          color: _hovered || _down
              ? (widget.tone ?? p.primaryVivid).withValues(
                  alpha: _down
                      ? PrismStateLayer.pressed(p.brightness)
                      : PrismStateLayer.hover(p.brightness),
                )
              : null,
        );
    }
  }

  BoxDecoration _baseDecoration(PrismColorScheme p) {
    final Color tone = widget.tone ?? p.primaryFill;
    if (!_enabled) {
      return BoxDecoration(borderRadius: PrismRadii.buttonAll, color: p.surfaceAlt);
    }
    switch (widget.variant) {
      case PrismButtonVariant.primary:
        final Color base =
            widget.tone == null ? p.primaryDark : Color.alphaBlend(const Color(0x3D000000), tone);
        return BoxDecoration(borderRadius: PrismRadii.buttonAll, color: base);
      case PrismButtonVariant.secondary:
        final Color base = Color.alphaBlend(
          tone.withValues(alpha: p.brightness == Brightness.dark ? 0.34 : 0.24),
          p.surfaceAlt,
        );
        return BoxDecoration(
          borderRadius: PrismRadii.buttonAll,
          color: base,
          border: Border.all(color: Color.alphaBlend(tone.withValues(alpha: 0.55), p.borderStrong)),
        );
      case PrismButtonVariant.ghost:
        return const BoxDecoration(borderRadius: PrismRadii.buttonAll);
    }
  }
}
