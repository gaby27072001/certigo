import 'package:certigo/app/capabilities/release_navigation.dart';
import 'package:certigo/app/route_paths.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every Alpha Core route remains enabled', () {
    const List<String> coreLocations = <String>[
      Routes.auth,
      Routes.home,
      Routes.path,
      Routes.library,
      '${Routes.lesson}/az-900/lesson-1',
      '${Routes.quiz}/az-900/lesson-1',
      Routes.profile,
    ];

    for (final String location in coreLocations) {
      expect(
        resolveReleaseRedirect(profile: ReleaseProfile.privateAlpha, location: location),
        isNull,
        reason: location,
      );
    }
  });

  test('Alpha upcoming and off deep links redirect before their screen is built', () {
    expect(
      resolveReleaseRedirect(profile: ReleaseProfile.privateAlpha, location: Routes.friends),
      capabilityUnavailableLocation(AppCapability.socialFriends),
    );
    expect(
      resolveReleaseRedirect(
        profile: ReleaseProfile.privateAlpha,
        location: '${Routes.registration}/name',
      ),
      capabilityUnavailableLocation(AppCapability.publicRegistration),
    );
  });

  test('generic unavailable route is stable while disabled and exits when enabled', () {
    final String unavailable = capabilityUnavailableLocation(AppCapability.socialFriends);

    expect(
      resolveReleaseRedirect(profile: ReleaseProfile.privateAlpha, location: unavailable),
      isNull,
    );
    expect(
      resolveReleaseRedirect(profile: ReleaseProfile.full, location: unavailable),
      Routes.home,
    );
  });

  test('full profile preserves every existing route', () {
    const List<String> locations = <String>[
      Routes.home,
      Routes.path,
      Routes.library,
      Routes.leaderboard,
      Routes.profile,
      Routes.achievements,
      Routes.seasons,
      Routes.quests,
      Routes.shop,
      Routes.friends,
      Routes.exam,
      Routes.dailyShare,
      Routes.accountDeletion,
    ];

    for (final String location in locations) {
      expect(
        resolveReleaseRedirect(profile: ReleaseProfile.full, location: location),
        isNull,
        reason: location,
      );
    }
  });

  test('operational safety policy still blocks destructive full-profile routes', () {
    const CapabilityRuntimePolicy policy = CapabilityRuntimePolicy(accountDeletionEnabled: false);

    expect(
      resolveReleaseRedirect(
        profile: ReleaseProfile.full,
        location: Routes.accountDeletion,
        runtimePolicy: policy,
      ),
      capabilityUnavailableLocation(AppCapability.accountDeletion),
    );
  });
}
