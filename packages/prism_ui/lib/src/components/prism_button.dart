import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_radii.dart';

/// Button hierarchy for Certigo.
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
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Duration fast = PrismMotion.resolve(context, PrismMotion.fast);
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
            child: Text(widget.label, style: labelStyle, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );

    return Semantics(
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
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
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
            child: AnimatedOpacity(
              opacity: _enabled ? 1 : 0.5,
              duration: fast,
              child: Container(
                foregroundDecoration: _focused
                    ? BoxDecoration(
                        borderRadius: PrismRadii.buttonAll,
                        border: Border.all(color: p.textPrimary, width: 2),
                      )
                    : null,
                child: SizedBox(
                  height: 54 + lip,
                  child: Stack(
                    children: <Widget>[
                      if (depth)
                        Positioned(
                          top: lip,
                          left: 0,
                          right: 0,
                          child: Container(height: 54, decoration: _baseDecoration(p)),
                        ),
                      AnimatedPositioned(
                        duration: fast,
                        curve: PrismMotion.standard,
                        top: sink,
                        left: 0,
                        right: 0,
                        child: AnimatedScale(
                          scale: _down ? 0.995 : 1.0,
                          duration: fast,
                          curve: PrismMotion.standard,
                          child: Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: _topDecoration(p),
                            alignment: Alignment.center,
                            child: content,
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
      ),
    );
  }

  Color _foreground(PrismColorScheme p) => switch (widget.variant) {
        PrismButtonVariant.primary => Colors.white,
        PrismButtonVariant.secondary => widget.tone ?? p.primary,
        PrismButtonVariant.ghost => widget.tone ?? p.textSecondary,
      };

  BoxDecoration _topDecoration(PrismColorScheme p) {
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
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: tone.withOpacity(p.brightness == Brightness.dark ? 0.42 : 0.32),
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

  BoxDecoration _baseDecoration(PrismColorScheme p) {
    final Color tone = widget.tone ?? p.primary;
    switch (widget.variant) {
      case PrismButtonVariant.primary:
        final Color base = widget.tone == null
            ? p.primaryDark
            : Color.alphaBlend(Colors.black.withOpacity(0.24), tone);
        return BoxDecoration(borderRadius: PrismRadii.buttonAll, color: base);
      case PrismButtonVariant.secondary:
        final Color base = Color.alphaBlend(
          tone.withOpacity(p.brightness == Brightness.dark ? 0.34 : 0.24),
          p.surfaceAlt,
        );
        return BoxDecoration(
          borderRadius: PrismRadii.buttonAll,
          color: base,
          border: Border.all(color: tone.withOpacity(0.30)),
        );
      case PrismButtonVariant.ghost:
        return const BoxDecoration(borderRadius: PrismRadii.buttonAll);
    }
  }
}
