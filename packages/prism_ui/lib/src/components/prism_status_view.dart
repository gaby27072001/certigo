import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import 'prism_button.dart';

/// A centered, full-bleed view for terminal empty / error states with an
/// optional CTA.
///
/// Loading states use [PrismSkeleton] instead; this is for "nothing here yet"
/// or "something went wrong, retry" moments.
class PrismStatusView extends StatelessWidget {
  const PrismStatusView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Convenience constructor for an offline / error state with a retry CTA.
  PrismStatusView.error({super.key, String? message, VoidCallback? onRetry})
      : icon = Icons.cloud_off_rounded,
        title = 'Connexion impossible',
        message = message ?? 'Vérifie ta connexion puis réessaie.',
        actionLabel = onRetry == null ? null : 'Réessayer',
        onAction = onRetry;

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: p.textSecondary),
            const SizedBox(height: 16),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                style: t.bodyMedium?.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 24),
              PrismButton.secondary(
                label: actionLabel!,
                onPressed: onAction,
                icon: Icons.refresh_rounded,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
