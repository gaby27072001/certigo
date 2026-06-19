import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import 'glass_surface.dart';

/// A "Scenario" / applied-example block — grounds an abstract concept in a
/// realistic Microsoft/Azure situation.
///
/// Info-tinted so it reads as "here is where this shows up in real work". The
/// applied example is what turns recall into transferable understanding.
class ScenarioBlock extends StatelessWidget {
  const ScenarioBlock({
    super.key,
    required this.body,
    this.title = 'Exemple Azure',
  });

  final String body;
  final String title;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return GlassSurface(
      tint: p.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lightbulb_rounded, color: p.info, size: 20),
              const SizedBox(width: 8),
              Text(title, style: t.labelLarge?.copyWith(color: p.info)),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: t.bodyLarge?.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}
