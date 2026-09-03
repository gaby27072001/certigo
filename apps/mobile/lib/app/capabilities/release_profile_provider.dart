import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime release profile.
///
/// [bootstrap] always overrides this provider after validating the explicit
/// compile-time selection. The full default preserves existing isolated widget
/// and provider tests that intentionally bypass production bootstrap.
final releaseProfileProvider = Provider<ReleaseProfile>((Ref ref) => ReleaseProfile.full);

/// Runtime operational gates layered over the selected product profile.
///
/// Production bootstrap overrides this with [AppEnv.capabilityRuntimePolicy].
/// The permissive default preserves isolated tests that intentionally bypass
/// bootstrap and explicitly exercise the full product behavior.
final capabilityRuntimePolicyProvider = Provider<CapabilityRuntimePolicy>(
  (Ref ref) => CapabilityRuntimePolicy.permissive,
);

final capabilityAvailabilityProvider = Provider.family<CapabilityAvailability, AppCapability>((
  Ref ref,
  AppCapability capability,
) {
  return ref
      .watch(capabilityRuntimePolicyProvider)
      .availabilityOf(ref.watch(releaseProfileProvider), capability);
});

class CapabilityUnavailableException implements Exception {
  const CapabilityUnavailableException(this.capability, this.availability);

  final AppCapability capability;
  final CapabilityAvailability availability;

  @override
  String toString() => 'Capability "${capability.id}" is ${availability.name}.';
}

/// Stops provider construction before a disabled capability can create a
/// network, storage, or permission-bearing service.
void requireEnabledCapability(Ref ref, AppCapability capability) {
  final CapabilityAvailability availability = ref.watch(capabilityAvailabilityProvider(capability));
  if (!availability.isEnabled) {
    throw CapabilityUnavailableException(capability, availability);
  }
}
