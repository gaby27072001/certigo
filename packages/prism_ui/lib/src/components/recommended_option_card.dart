import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_radii.dart';

/// A large, selectable option card with an optional **RECOMMANDÉ** badge — the
/// hero decision widget for the paywall ("Premium / Gratuit") and the
/// "where do I start?" question, where two big choices sit side by side.
///
/// Shares the tactile language of [ChoiceTile] (accent border, tinted fill,
/// pressable bottom "lip") but scales up to a headline + description + trailing
/// slot, and floats a pill badge above the top edge when [recommended].
class RecommendedOptionCard extends StatefulWidget {
  const RecommendedOptionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.recommended = false,
    this.badgeLabel = 'RECOMMANDÉ',
    this.onTap,
    this.accent,
  });

  /// Bold headline of the option.
  final String title;

  /// Optional supporting description.
  final String? subtitle;

  /// Optional leading glyph (icon / emoji).
  final Widget? leading;

  /// Optional trailing slot (e.g. a price or a chevron).
  final Widget? trailing;

  final bool selected;

  /// Floats the [badgeLabel] pill over the top edge when true.
  final bool recommended;
  final String badgeLabel;

  final VoidCallback? onTap;

  /// Selection hue. Defaults to the brand primary.
  final Color? accent;

  @override
  State<RecommendedOptionCard> createState() => _RecommendedOptionCardState();
}

class _RecommendedOptionCardState extends State<RecommendedOptionCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
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

    final Widget card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!.call();
            },
      child: AnimatedContainer(
        duration: duration,
        curve: PrismMotion.standard,
        margin: EdgeInsets.only(bottom: _down ? 0 : 4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: PrismRadii.cardXl,
          border: Border.all(color: border, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(color: lip, offset: Offset(0, _down ? 0 : 4), blurRadius: 0),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: <Widget>[
            if (widget.leading != null) ...<Widget>[
              SizedBox(width: 40, height: 40, child: Center(child: widget.leading)),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...<Widget>[const SizedBox(width: 12), widget.trailing!],
          ],
        ),
      ),
    );

    if (!widget.recommended) {
      return Semantics(button: true, selected: sel, label: widget.title, child: card);
    }

    // Floating badge above the top edge; extra top padding reserves its room.
    return Semantics(
      button: true,
      selected: sel,
      label: '${widget.badgeLabel}, ${widget.title}',
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            card,
            Positioned(
              top: -10,
              left: 18,
              child: _Badge(label: widget.badgeLabel, accent: accent),
            ),
          ],
        ),
      ),
    );
  }

  static Color _shift(Color c, double amount) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: PrismRadii.pillAll,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
