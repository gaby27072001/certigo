import 'package:core/core.dart';

import '../route_paths.dart';

AppCapability? capabilityForLocation(String location) {
  final String path = Uri.tryParse(location)?.path ?? location;
  if (path.startsWith(Routes.registration)) {
    return AppCapability.publicRegistration;
  }
  if (path.startsWith(Routes.lesson)) {
    return AppCapability.lessons;
  }
  if (path.startsWith(Routes.quiz)) return AppCapability.quizCorrection;
  if (path.startsWith(Routes.library)) return AppCapability.certificationCatalog;
  return switch (path) {
    Routes.splash || Routes.landing || Routes.auth => AppCapability.authentication,
    Routes.home || Routes.profile => AppCapability.progressionReadinessXp,
    Routes.path => AppCapability.learningPath,
    Routes.leaderboard => AppCapability.socialLeague,
    Routes.achievements => AppCapability.achievements,
    Routes.seasons => AppCapability.seasons,
    Routes.quests => AppCapability.quests,
    Routes.shop => AppCapability.shop,
    Routes.friends => AppCapability.socialFriends,
    Routes.exam => AppCapability.mockExam,
    Routes.dailyShare => AppCapability.socialSharing,
    Routes.accountDeletion || Routes.accountDeleted => AppCapability.accountDeletion,
    _ => null,
  };
}

AppCapability? unavailableCapabilityForLocation(String location) {
  final String path = Uri.tryParse(location)?.path ?? location;
  const String prefix = '${Routes.capabilityUnavailable}/';
  if (!path.startsWith(prefix)) return null;
  return AppCapability.fromId(path.substring(prefix.length));
}

String capabilityUnavailableLocation(AppCapability capability) =>
    '${Routes.capabilityUnavailable}/${capability.id}';

/// Returns a safe generic route before any gated screen/provider is built.
String? resolveReleaseRedirect({
  required ReleaseProfile profile,
  required String location,
  CapabilityRuntimePolicy runtimePolicy = CapabilityRuntimePolicy.permissive,
}) {
  final AppCapability? unavailable = unavailableCapabilityForLocation(location);
  if (unavailable != null) {
    return runtimePolicy.availabilityOf(profile, unavailable).isEnabled ? Routes.home : null;
  }
  if ((Uri.tryParse(location)?.path ?? location).startsWith(Routes.capabilityUnavailable)) {
    return null;
  }
  final AppCapability? capability = capabilityForLocation(location);
  if (capability == null || runtimePolicy.availabilityOf(profile, capability).isEnabled) {
    return null;
  }
  return capabilityUnavailableLocation(capability);
}
