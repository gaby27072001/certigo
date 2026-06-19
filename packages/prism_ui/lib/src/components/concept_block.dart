import 'package:flutter/material.dart';

/// A "Concept" block — the core explanation, rendered as clean reading text on
/// the aurora canvas (no heavy surface) so comprehension stays the priority.
///
/// Body is plain text with generous line-height; an optional [title] introduces
/// the idea. This is the most-used block in a technical lesson.
class ConceptBlock extends StatelessWidget {
  const ConceptBlock({super.key, required this.body, this.title});

  final String body;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Text(title!, style: t.titleLarge),
          const SizedBox(height: 10),
        ],
        Text(body, style: t.bodyLarge?.copyWith(height: 1.55)),
      ],
    );
  }
}
