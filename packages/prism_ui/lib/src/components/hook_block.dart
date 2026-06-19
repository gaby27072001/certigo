import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import 'glass_surface.dart';

/// A "Hook" block — the curiosity gap that opens the Learn Loop.
///
/// Renders a glowing, ember-tinted glass card so the learner feels invited in
/// before any dense concept arrives. Keep the text to one provocative question.
class HookBlock extends StatelessWidget {
  const HookBlock({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return GlassSurface(
      tint: p.ember,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.bolt_rounded, color: p.ember),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: t.titleMedium?.copyWith(height: 1.35)),
          ),
        ],
      ),
    );
  }
}
