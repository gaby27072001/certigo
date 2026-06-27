import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Inline error banner for above-shell screens where no SnackBar host
/// is available.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.error.withValues(alpha: 0.12),
        borderRadius: PrismRadii.cardMd,
        border: Border.all(color: p.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: p.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: t.bodySmall?.copyWith(color: p.error)),
          ),
        ],
      ),
    );
  }
}
