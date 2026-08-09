import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// A compact, gold-accented chip showing accumulated XP.
///
/// The canonical XP component (prefer it over the generic [StatPill]). Large
/// totals are abbreviated (1.2k, 3.4M). An optional [delta] surfaces XP just
/// earned (e.g. `+30`) in the success tone for a quick reward beat.
class XpChip extends StatelessWidget {
  const XpChip({super.key, required this.xp, this.delta});

  /// Total experience points.
  final int xp;

  /// Optional "just earned" amount rendered as `+delta`.
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return Semantics(
      label: '$xp points d\'expérience',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: PrismRadii.pillAll,
          border: Border.all(color: p.xpGold.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.bolt_rounded, size: 18, color: p.xpGold),
            const SizedBox(width: 6),
            Text(
              _compact(xp),
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
