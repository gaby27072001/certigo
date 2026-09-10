import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_state.dart';

enum PrismHaptic { none, selection, light }

/// Shared tactile wrapper for Prism surfaces.
///
/// Every state a control can be in is rendered here, from one vocabulary:
/// rest, hover, pressed, focus, selected and disabled. Two defects used to
/// live in this file:
///
/// * `overlayColor: Colors.transparent` switched off Material's state layers,
///   so **hover did not exist** — most obviously on the web build, which is
///   the one under test.
/// * The focus ring was hard-coded `Colors.black` over `Colors.white`, so it
///   ignored the theme entirely and clashed with `PrismButton`, which drew a
///   different ring in `textPrimary`.
///
/// The ring is now themed, drawn outside the control with a gap in the surface
/// colour, and identical everywhere.
class PrismPressable extends StatefulWidget {
  const PrismPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = BorderRadius.zero,
    this.pressedScale = PrismStateLayer.pressedScale,
    this.haptic = PrismHaptic.none,
    this.semanticLabel,
    this.selected,
    this.tint,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;
  final double pressedScale;
  final PrismHaptic haptic;
  final String? semanticLabel;
  final bool? selected;

  /// Accent this control adopts for its state layers, so a control inside a
  /// track-coloured region highlights in that track's hue.
  final Color? tint;

  final bool enabled;

  @override
  State<PrismPressable> createState() => _PrismPressableState();
}

class _PrismPressableState extends State<PrismPressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  void _handleTap() {
    switch (widget.haptic) {
      case PrismHaptic.none:
        break;
      case PrismHaptic.selection:
        HapticFeedback.selectionClick();
        break;
      case PrismHaptic.light:
        HapticFeedback.lightImpact();
        break;
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Color tint = widget.tint ?? p.primaryVivid;
    final bool enabled = widget.enabled;

    // The state layer is painted over the child rather than under it, so it
    // works no matter what the child draws.
    double? overlayAlpha;
    if (!enabled) {
      overlayAlpha = null;
    } else if (_pressed) {
      overlayAlpha = PrismStateLayer.pressed(p.brightness);
    } else if (_hovered) {
      overlayAlpha = PrismStateLayer.hover(p.brightness);
    } else if (widget.selected ?? false) {
      overlayAlpha = PrismStateLayer.selected(p.brightness);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      selected: widget.selected,
      child: AnimatedScale(
        scale: _pressed && enabled ? widget.pressedScale : 1,
        duration: PrismMotion.resolve(context, PrismMotion.state),
        curve: PrismMotion.continuous,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : PrismStateLayer.disabledSurface,
          duration: PrismMotion.resolve(context, PrismMotion.state),
          child: Stack(
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: widget.borderRadius,
                  // Prism paints its own state layers below, so Material's
                  // ripple is suppressed here rather than the whole state
                  // system being switched off.
                  overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
                  onHover: (bool value) {
                    if (_hovered != value) setState(() => _hovered = value);
                  },
                  onFocusChange: (bool value) {
                    if (_focused != value) setState(() => _focused = value);
                  },
                  onHighlightChanged: (bool value) {
                    if (_pressed != value) setState(() => _pressed = value);
                  },
                  onTap: enabled ? _handleTap : null,
                  child: widget.child,
                ),
              ),
              if (overlayAlpha != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: PrismMotion.resolve(context, PrismMotion.state),
                      curve: PrismMotion.continuous,
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        color: tint.withValues(alpha: overlayAlpha),
                      ),
                    ),
                  ),
                ),
              if (_focused && enabled)
                Positioned.fill(
                    child: IgnorePointer(
                        child: PrismFocusIndicator(
                  borderRadius: widget.borderRadius,
                  ringColor: p.focusRing,
                  gapColor: p.surface,
                ))),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one focus indicator used across Certigo.
///
/// A coloured ring separated from the control by a gap in the surface colour.
/// The gap is what lets a single ring colour stay visible on any background,
/// including on a filled button painted in that same colour.
class PrismFocusIndicator extends StatelessWidget {
  const PrismFocusIndicator({
    super.key,
    required this.borderRadius,
    required this.ringColor,
    required this.gapColor,
  });

  final BorderRadius borderRadius;
  final Color ringColor;
  final Color gapColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: gapColor, width: PrismFocusRing.gap),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PrismFocusRing.gap),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: ringColor, width: PrismFocusRing.width),
          ),
        ),
      ),
    );
  }
}
