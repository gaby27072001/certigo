import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../route_paths.dart';
import 'release_profile_provider.dart';
import 'release_strings.dart';

class FeatureUnavailableScreen extends ConsumerWidget {
  const FeatureUnavailableScreen({super.key, required this.capability});

  final AppCapability? capability;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CapabilityAvailability availability = capability == null
        ? CapabilityAvailability.off
        : ref.watch(capabilityAvailabilityProvider(capability!));
    final ReleaseStrings strings = ReleaseStrings.of(context);
    final bool registration = capability == AppCapability.publicRegistration;
    return Scaffold(
      body: SafeArea(
        child: PrismStatusView(
          icon: availability == CapabilityAvailability.upcoming
              ? Icons.schedule_rounded
              : Icons.lock_outline_rounded,
          title: strings.unavailableTitle(availability),
          message: strings.unavailableMessage(capability, availability),
          actionLabel: registration ? strings.backToSignIn : strings.backToApp,
          onAction: () => context.go(registration ? Routes.auth : Routes.home),
        ),
      ),
    );
  }
}
