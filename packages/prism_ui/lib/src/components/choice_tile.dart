import 'package:flutter/material.dart';

import '../feedback/prism_haptics.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_radii.dart';

/// A chunky, selectable option row — the workhorse of the onboarding wizard and
/// any "pick one / pick many" question.
///
/// Mirrors the playful card with a subtle bottom "lip" (a 2px darker base that
/// gives a tactile, pressable feel), a leading glyph, a bold title, an optional
/// right-aligned label and a trailing selection box. Selecting it lifts the
/// border and tints the surface with [accent].
class ChoiceTile extends StatefulWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    this.leading,
    this.trailingLabel,
    this.selected = false,
    this.onTap,
    this.showCheckbox = true,
    this.accent,
  });

  /// Primary, bold label.
  final String title;

  /// Optional leading glyph: an icon, an emoji [Text], a flag, etc.
  final Widget? leading;

  /// Optional right-aligned secondary label (e.g. "Tranquille", "10 min").
  final String? trailingLabel;

  final bool selected;
  final VoidCallback? onTap;

  /// Whether to render the trailing selection box. Off for "label-only" rows
  /// that signal selection through the highlighted border alone.
  final bool showCheckbox;

  /// Selection hue. Defaults to the brand primary.
  final Color? accent;

  @override
  State<ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<ChoiceTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Color accent = widget.accent ?? p.primary;
    final bool sel = widget.selected;

    final Color border = sel ? accent : p.border;
    final Color lip = sel ? _shift(accent, -0.12) : _shift(p.border, -0.06);
    final Color fill = sel
        ? Color.alphaBlend(
            accent.withOpacity(p.brightness == Brightness.dark ? 0.20 : 0.08),
            p.surface,
          )
        : p.surface;
    final Duration duration = PrismMotion.resolve(context, PrismMotion.fast);

    return Semantics(
      button: true,
      selected: sel,
      label: widget.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                PrismHaptics.selection();
                widget.onTap!.call();
              },
        child: AnimatedContainer(
          duration: duration,
          curve: PrismMotion.standard,
          // The bottom lip shrinks on press for a satisfying "click".
          margin: EdgeInsets.only(bottom: _down ? 0 : 3),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: PrismRadii.cardLg,
            border: Border.all(color: border, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(color: lip, offset: Offset(0, _down ? 0 : 3), blurRadius: 0),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: <Widget>[
              if (widget.leading != null) ...<Widget>[
                SizedBox(width: 34, height: 34, child: Center(child: widget.leading)),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (widget.trailingLabel != null) ...<Widget>[
                const SizedBox(width: 10),
                Text(
                  widget.trailingLabel!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: sel ? accent : p.textSecondary,
                  ),
                ),
              ],
              if (widget.showCheckbox) ...<Widget>[
                const SizedBox(width: 12),
                _Checkbox(selected: sel, accent: accent, border: p.border, duration: duration),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _shift(Color c, double amount) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.selected,
    required this.accent,
    required this.border,
    required this.duration,
  });

  final bool selected;
  final Color accent;
  final Color border;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? accent : border, width: 2),
      ),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: PrismMotion.spring,
        switchOutCurve: PrismMotion.standard,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: selected
            ? const Icon(
                Icons.check_rounded,
                key: ValueKey<String>('choice-check'),
                size: 17,
                color: Colors.white,
              )
            : const SizedBox.shrink(key: ValueKey<String>('choice-empty')),
      ),
    );
  }
}
