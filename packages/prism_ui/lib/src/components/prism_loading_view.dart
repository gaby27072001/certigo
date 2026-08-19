import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_spacing.dart';
import 'prism_skeleton.dart';

/// Coherent full-screen loading state for async surfaces without a known shape.
class PrismLoadingView extends StatelessWidget {
  const PrismLoadingView({
    super.key,
    this.label = 'Chargement en cours…',
    this.showSkeleton = true,
  });

  final String label;
  final bool showSkeleton;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(PrismSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: p.primary,
                    backgroundColor: p.primarySoft,
                  ),
                ),
                const SizedBox(height: PrismSpacing.md),
                ExcludeSemantics(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: p.textSecondary),
                  ),
                ),
                if (showSkeleton) ...<Widget>[
                  const SizedBox(height: PrismSpacing.lg),
                  const PrismSkeleton(height: 12),
                  const SizedBox(height: PrismSpacing.xs),
                  const PrismSkeleton(width: 220, height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
