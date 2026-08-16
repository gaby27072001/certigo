import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_spacing.dart';

/// Consistent title row for sections inside a page.
class PrismSectionHeader extends StatelessWidget {
  const PrismSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.compact = false,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool compact;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = iconColor ?? p.primary;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              width: compact ? 32 : 38,
              height: compact ? 32 : 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: p.brightness == Brightness.dark ? 0.20 : 0.10),
                  shape: BoxShape.circle),
              child: Icon(icon, size: compact ? 17 : 20, color: accent),
            ),
            const SizedBox(width: PrismSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: compact ? text.titleMedium : text.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: PrismSpacing.xxs),
                  Text(subtitle!, style: text.bodySmall?.copyWith(color: p.textSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: PrismSpacing.sm), trailing!],
        ],
      ),
    );
  }
}
