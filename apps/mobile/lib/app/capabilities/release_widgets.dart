import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import 'release_profile_provider.dart';
import 'release_strings.dart';

typedef CapabilityChildBuilder =
    Widget Function(BuildContext context, CapabilityAvailability availability);

/// Stable interaction boundary for a capability-backed navigation entry.
///
/// Disabled and upcoming branches have no recognizer, callback, haptic, or
/// focus action; the builder can still render an honest preview in place.
class CapabilityAction extends ConsumerWidget {
  const CapabilityAction({
    super.key,
    required this.capability,
    required this.semanticLabel,
    required this.onPressed,
    required this.builder,
    this.borderRadius = PrismRadii.cardLg,
    this.haptic = PrismHaptic.light,
    this.showWhenOff = false,
  });

  final AppCapability capability;
  final String semanticLabel;
  final VoidCallback onPressed;
  final CapabilityChildBuilder builder;
  final BorderRadius borderRadius;
  final PrismHaptic haptic;
  final bool showWhenOff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CapabilityAvailability availability = ref.watch(
      capabilityAvailabilityProvider(capability),
    );
    if (availability == CapabilityAvailability.off && !showWhenOff) {
      return const SizedBox.shrink();
    }
    final Widget child = builder(context, availability);
    if (availability.isEnabled) {
      return PrismPressable(
        semanticLabel: semanticLabel,
        borderRadius: borderRadius,
        haptic: haptic,
        onPressed: onPressed,
        child: child,
      );
    }
    final ReleaseStrings strings = ReleaseStrings.of(context);
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: strings.unavailableSemantics(semanticLabel, availability),
      child: ExcludeSemantics(child: child),
    );
  }
}

class CapabilityStatusBadge extends StatelessWidget {
  const CapabilityStatusBadge({super.key, required this.availability});

  final CapabilityAvailability availability;

  @override
  Widget build(BuildContext context) {
    if (availability.isEnabled) return const SizedBox.shrink();
    final PrismColorScheme p = context.prism;
    final ReleaseStrings strings = ReleaseStrings.of(context);
    final String label = availability == CapabilityAvailability.upcoming
        ? strings.soon
        : strings.unavailable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: PrismRadii.pillAll,
        border: Border.all(color: p.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class CapabilitySecondaryButton extends ConsumerWidget {
  const CapabilitySecondaryButton({
    super.key,
    required this.capability,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final AppCapability capability;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CapabilityAvailability availability = ref.watch(
      capabilityAvailabilityProvider(capability),
    );
    if (availability == CapabilityAvailability.off) {
      return const SizedBox.shrink();
    }
    if (availability.isEnabled) {
      return PrismButton.secondary(label: label, icon: icon, onPressed: onPressed);
    }
    final PrismColorScheme p = context.prism;
    final ReleaseStrings strings = ReleaseStrings.of(context);
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: strings.unavailableSemantics(label, availability),
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: PrismRadii.buttonAll,
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: PrismSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, size: 20, color: p.textSecondary),
                    const SizedBox(width: PrismSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PrismSpacing.xxs),
              CapabilityStatusBadge(availability: availability),
              const SizedBox(height: PrismSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
