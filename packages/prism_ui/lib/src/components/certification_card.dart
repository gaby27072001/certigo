import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_spacing.dart';

/// One Duolingo-style certification card: a colored emblem with the exam code,
/// the official title, an optional level chip and lesson/chapter counts, plus a
/// selected mark.
///
/// This is the public, design-system component behind the course picker sheet,
/// the vendor certifications catalogue and the onboarding certification choice.
/// It is intentionally **data-model-free** — callers pass primitive fields — so
/// `prism_ui` stays dependency-free and the same card renders a `TrackSummary`
/// (catalogue) or a `TargetCertification` (onboarding) alike.
class CertificationCard extends StatelessWidget {
  const CertificationCard({
    super.key,
    required this.code,
    required this.title,
    required this.accent,
    this.summary = '',
    this.levelLabel = '',
    this.lessonCount,
    this.unitCount,
    this.selected = false,
    this.onTap,
  });

  /// Official exam code, e.g. "AZ-900" — shown big on the emblem.
  final String code;

  /// Official certification title (kept in the vendor's English wording).
  final String title;

  /// Per-domain accent color for the emblem, chip and selected state.
  final Color accent;

  /// Optional one-line French description under the title.
  final String summary;

  /// Optional already-localised level label (e.g. "Fondamentaux"). Hidden when
  /// empty.
  final String levelLabel;

  /// Number of lessons; shown in the counts row only when both counts are set.
  final int? lessonCount;

  /// Number of units (chapters); shown with [lessonCount].
  final int? unitCount;

  /// Whether this card is the currently selected certification.
  final bool selected;

  /// Tap handler; when null the card is inert (pure display).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final bool showCounts = lessonCount != null && unitCount != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: PrismRadii.cardXl,
        child: Container(
          padding: const EdgeInsets.all(PrismSpacing.debt14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.10) : p.surface,
            borderRadius: PrismRadii.cardXl,
            border: Border.all(color: selected ? accent : p.border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: <Widget>[
              _Emblem(code: code, accent: accent),
              const SizedBox(width: PrismSpacing.debt14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: PrismSpacing.debt3),
                      Text(
                        summary,
                        style: text.bodySmall?.copyWith(color: p.textSecondary, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (levelLabel.isNotEmpty || showCounts) ...<Widget>[
                      const SizedBox(height: PrismSpacing.debt9),
                      Row(
                        children: <Widget>[
                          if (levelLabel.isNotEmpty) ...<Widget>[
                            _MetaChip(label: levelLabel, color: accent),
                            const SizedBox(width: PrismSpacing.xs),
                          ],
                          if (showCounts) ...<Widget>[
                            Icon(Icons.menu_book_rounded, size: 14, color: p.textSecondary),
                            const SizedBox(width: PrismSpacing.xxs),
                            Flexible(
                              child: Text(
                                '$lessonCount leçons · $unitCount chapitres',
                                style: text.labelSmall?.copyWith(color: p.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: PrismSpacing.xs),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? accent : p.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gradient emblem carrying the exam code — the colourful anchor of a card.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.code, required this.accent});

  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[accent, accent.withOpacity(0.74)],
        ),
        borderRadius: PrismRadii.cardLg,
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// A small pill labelling the certification level (accent-tinted).
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.xs,
        vertical: PrismSpacing.debt3,
      ),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: PrismRadii.pillAll),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
