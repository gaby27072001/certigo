import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

class TappableRow extends StatelessWidget {
  const TappableRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.trailingColor,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: trailingColor ?? p.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: t.bodyLarge?.copyWith(color: trailingColor),
            ),
          ),
          if (trailing != null) Text(trailing!, style: t.labelMedium?.copyWith(color: p.primary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 18),
        ],
      ),
    );
  }
}
