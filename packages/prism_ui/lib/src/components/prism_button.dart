import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_elevation.dart';

/// Button hierarchy for Microlingo.
///
/// * [PrismButtonVariant.primary] — the single most important action on a
///   screen (Continue, Start lesson, Submit). Solid brand gradient + glow.
/// * [PrismButtonVariant.secondary] — supporting actions. Glass/tonal.
/// * [PrismButtonVariant.ghost] — low-emphasis / tertiary. Text-like.
///
/// Provides press scale + haptics and a built-in [loading] state so call sites
/// never have to reimplement button busy logic.
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
  });

  const PrismButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.tone,
  }) : variant = PrismButtonVariant.secondary;

  const PrismButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.tone,
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

  @override
  State<PrismButton> createState() => _PrismButtonState();
}

class _PrismButtonState extends State<PrismButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextStyle labelStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
          color: _foreground(p),
          fontWeight: FontWeight.w700,
        );

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
          Flexible(child: Text(widget.label, style: labelStyle, overflow: TextOverflow.ellipsis)),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTap: _enabled ? _handleTap : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.5,
            duration: const Duration(milliseconds: 160),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: _decoration(p),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Color _foreground(PrismColorScheme p) => switch (widget.variant) {
        PrismButtonVariant.primary => Colors.white,
        PrismButtonVariant.secondary => widget.tone ?? p.primary,
        PrismButtonVariant.ghost => widget.tone ?? p.textSecondary,
      };

  BoxDecoration _decoration(PrismColorScheme p) {
    final Color tone = widget.tone ?? p.primary;
    switch (widget.variant) {
      case PrismButtonVariant.primary:
        final Color toneDark = widget.tone == null
            ? p.primaryDark
            : Color.alphaBlend(Colors.black.withOpacity(0.16), tone);
        return BoxDecoration(
          borderRadius: PrismRadii.buttonAll,
          gradient: LinearGradient(
            colors: <Color>[tone, toneDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: _down
              ? PrismElevation.level0
              : <BoxShadow>[
                  BoxShadow(
                    color: tone.withOpacity(
                      p.brightness == Brightness.dark ? 0.42 : 0.32,
                    ),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                    spreadRadius: -6,
                  ),
                ],
        );
      case PrismButtonVariant.secondary:
        return BoxDecoration(
          borderRadius: PrismRadii.buttonAll,
          color: Color.alphaBlend(
            tone.withOpacity(p.brightness == Brightness.dark ? 0.20 : 0.12),
            p.surface,
          ),
          border: Border.all(color: tone.withOpacity(0.30)),
        );
      case PrismButtonVariant.ghost:
        return const BoxDecoration(borderRadius: PrismRadii.buttonAll);
    }
  }
}
