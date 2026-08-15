import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// The streak signature of Certigo: a flame badge showing the number of
/// consecutive active days.
///
/// This is the canonical, semantic streak component (prefer it over the generic
/// [StatPill]). When [active] is false (the day's goal isn't met yet) the flame
/// cools to a muted tone and the ember halo is dropped — a gentle nudge, never a
/// punishment.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days, this.active = true});

  /// Current streak length in days.
  final int days;

  /// Whether today's streak is already secured.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color flame = active ? p.ember : p.textSecondary;

    return Semantics(
      label: 'Série de $days jours${active ? '' : ' — à sécuriser aujourd\'hui'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: PrismRadii.pillAll,
          border: Border.all(color: active ? p.ember.withOpacity(0.35) : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.local_fire_department_rounded, size: 18, color: flame),
            const SizedBox(width: 6),
            Text(
              '$days',
              style: t.labelLarge?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
