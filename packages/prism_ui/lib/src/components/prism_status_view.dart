import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_spacing.dart';
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
    this.tone,
  });

  /// Convenience constructor for an offline / error state with a retry CTA.
  const PrismStatusView.error({super.key, String? message, VoidCallback? onRetry})
      : icon = Icons.cloud_off_rounded,
        title = 'Connexion impossible',
        message = message ?? 'Vérifie ta connexion puis réessaie.',
        actionLabel = onRetry == null ? null : 'Réessayer',
        onAction = onRetry,
        tone = null;

  const PrismStatusView.empty({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_rounded,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color accent = tone ?? (icon == Icons.cloud_off_rounded ? p.error : p.primary);
    return Semantics(
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(PrismSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: p.brightness == Brightness.dark ? 0.20 : 0.10),
                    borderRadius: PrismRadii.cardXl,
                    border: Border.all(color: accent.withValues(alpha: 0.20)),
                  ),
                  child: Icon(icon, size: 32, color: accent),
                ),
                const SizedBox(height: PrismSpacing.lg),
                Text(title, style: t.titleLarge, textAlign: TextAlign.center),
                if (message != null) ...<Widget>[
                  const SizedBox(height: PrismSpacing.xs),
                  Text(
                    message!,
                    style: t.bodyMedium?.copyWith(color: p.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: PrismSpacing.lg),
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
        ),
      ),
    );
  }
}
