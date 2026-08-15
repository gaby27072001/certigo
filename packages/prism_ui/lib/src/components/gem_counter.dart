import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// A compact, cyan-accented chip showing the learner's soft currency (gems).
///
/// The canonical economy component for the home top bar (prefer it over the
/// generic [StatPill]). Large totals are abbreviated (1.2k, 3.4M). An optional
/// [delta] surfaces gems just earned (e.g. `+5`) in the success tone for a quick
/// reward beat, mirroring [XpChip] and [StreakBadge].
class GemCounter extends StatelessWidget {
  const GemCounter({super.key, required this.gems, this.delta});

  /// Total gems owned.
  final int gems;

  /// Optional "just earned" amount rendered as `+delta`.
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return Semantics(
      label: '$gems gemmes',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: PrismRadii.pillAll,
          border: Border.all(color: p.info.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.diamond_rounded, size: 17, color: p.info),
            const SizedBox(width: 6),
            Text(
              _compact(gems),
              style: t.labelLarge?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800),
            ),
            if (delta != null && delta! > 0) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                '+${_compact(delta!)}',
                style: t.labelMedium?.copyWith(color: p.success, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
