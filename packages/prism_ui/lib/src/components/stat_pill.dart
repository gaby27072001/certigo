import 'package:flutter/material.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// A compact pill that surfaces a single gamification stat (streak, XP, energy).
///
/// Used in app bars and the home header. Kept tiny and glanceable; the icon
/// color carries the meaning (ember = streak, gold = XP).
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    this.semanticLabel,
  });

  /// Streak pill (ember flame).
  factory StatPill.streak(int days, {Color? color}) => StatPill(
    icon: Icons.local_fire_department_rounded,
    value: '$days',
    color: color ?? const Color(0xFFFF7A45),
    semanticLabel: 'Série de $days jours',
  );

  /// XP pill (gold bolt).
  factory StatPill.xp(int xp, {Color? color}) => StatPill(
    icon: Icons.bolt_rounded,
    value: _compact(xp),
    color: color ?? const Color(0xFFFFC24B),
    semanticLabel: '$xp points d\'expérience',
  );

  final IconData icon;
  final String value;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: PrismRadii.pillAll,
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
            ),
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
