import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

class BadgeData {
  const BadgeData(this.icon, this.label, this.color, this.unlocked);

  final IconData icon;
  final String label;
  final Color color;
  final bool unlocked;
}

class ProfileBadge extends StatelessWidget {
  const ProfileBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return SizedBox(
      width: 88,
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: locked ? p.surfaceAlt : color.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: locked ? p.border : color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: locked ? p.textSecondary : color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t.labelSmall?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}
