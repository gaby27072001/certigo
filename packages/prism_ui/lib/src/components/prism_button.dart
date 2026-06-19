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
  });

  const PrismButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = PrismButtonVariant.secondary;

  const PrismButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = PrismButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final PrismButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

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

    Widget content = Row(
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
        PrismButtonVariant.secondary => p.primary,
        PrismButtonVariant.ghost => p.textSecondary,
      };

  BoxDecoration _decoration(PrismColorScheme p) {
    switch (widget.variant) {
      case PrismButtonVariant.primary:
        return BoxDecoration(
          borderRadius: PrismRadii.cardLg,
          gradient: LinearGradient(
            colors: <Color>[p.primary, p.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: _down ? PrismElevation.level0 : PrismElevation.level3(p.brightness),
        );
      case PrismButtonVariant.secondary:
        return BoxDecoration(
          borderRadius: PrismRadii.cardLg,
          color: p.primarySoft,
          border: Border.all(color: p.primary.withOpacity(0.25)),
        );
      case PrismButtonVariant.ghost:
        return const BoxDecoration(borderRadius: PrismRadii.cardLg);
    }
  }
}
