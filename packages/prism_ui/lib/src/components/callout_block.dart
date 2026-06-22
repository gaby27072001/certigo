import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import 'prism_card.dart';

/// The semantic intent of a [CalloutBlock].
enum CalloutKind { info, warning, success }

/// A compact, tinted note that flags a pitfall, a tip or a confirmation inside a
/// lesson. Distinct from [HookBlock] / [ScenarioBlock]: this is a short aside,
/// not a primary teaching surface — perfect for "Common mistake" or "Exam tip".
class CalloutBlock extends StatelessWidget {
  const CalloutBlock({
    super.key,
    required this.kind,
    required this.text,
    this.title,
  });

  final CalloutKind kind;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final (Color color, IconData icon) = switch (kind) {
      CalloutKind.info => (p.info, Icons.info_rounded),
      CalloutKind.warning => (p.warning, Icons.warning_amber_rounded),
      CalloutKind.success => (p.success, Icons.check_circle_rounded),
    };
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(title!, style: t.labelLarge?.copyWith(color: color)),
                  const SizedBox(height: 4),
                ],
                Text(text, style: t.bodyMedium?.copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
