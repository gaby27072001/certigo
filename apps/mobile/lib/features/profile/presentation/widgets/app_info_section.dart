import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

class AppInfoSection extends StatelessWidget {
  const AppInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return PrismCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded, color: p.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Version de l\'app', style: t.bodyLarge)),
              Text('0.1.0 (build 1)', style: t.labelMedium?.copyWith(color: p.textSecondary)),
            ],
          ),
          Divider(color: p.border, height: 24),
          InkWell(
            onTap: () => showLicensePage(context: context, applicationName: 'Certigo'),
            borderRadius: BorderRadius.circular(PrismRadii.sm),
            child: Row(
              children: <Widget>[
                Icon(Icons.description_outlined, color: p.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Licences', style: t.bodyLarge)),
                Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
