import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/prism_motion.dart';

enum PrismHaptic { none, selection, light }

/// Shared tactile wrapper for Prism surfaces.
///
/// Feedback starts on pointer-down, remains keyboard accessible through
/// [InkWell], and becomes instantaneous when reduced motion is enabled.
class PrismPressable extends StatefulWidget {
  const PrismPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = BorderRadius.zero,
    this.pressedScale = 0.97,
    this.haptic = PrismHaptic.none,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;
  final double pressedScale;
  final PrismHaptic haptic;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<PrismPressable> createState() => _PrismPressableState();
}

class _PrismPressableState extends State<PrismPressable> {
  bool _pressed = false;
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
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      selected: widget.selected,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: PrismMotion.resolve(context, PrismMotion.fast),
        curve: PrismMotion.standard,
        child: Stack(
          children: <Widget>[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: widget.borderRadius,
                overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
                onFocusChange: (bool value) {
                  if (_focused != value) setState(() => _focused = value);
                },
                onHighlightChanged: (bool value) {
                  if (_pressed != value) {
                    setState(() => _pressed = value);
                  }
                },
                onTap: _handleTap,
                child: widget.child,
              ),
            ),
            if (_focused)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius,
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: widget.borderRadius,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
