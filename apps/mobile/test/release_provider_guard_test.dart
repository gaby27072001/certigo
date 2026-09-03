import 'package:certigo/app/capabilities/release_profile_provider.dart';
import 'package:certigo/app/providers.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Alpha upcoming providers stop before constructing network dependencies', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[releaseProfileProvider.overrideWithValue(ReleaseProfile.privateAlpha)],
    );
    addTearDown(container.dispose);

    void expectGuarded(Object? Function() read, AppCapability capability) {
      expect(
        read,
        throwsA(
          isA<CapabilityUnavailableException>()
              .having(
                (CapabilityUnavailableException error) => error.capability,
                'capability',
                capability,
              )
              .having(
                (CapabilityUnavailableException error) => error.availability,
                'availability',
                CapabilityAvailability.upcoming,
              ),
        ),
      );
    }

    expectGuarded(() => container.read(leaderboardRepositoryProvider), AppCapability.socialLeague);
    expectGuarded(() => container.read(friendRepositoryProvider), AppCapability.socialFriends);
    expectGuarded(() => container.read(shareCardRepositoryProvider), AppCapability.socialSharing);
    expectGuarded(() => container.read(tutorRepositoryProvider), AppCapability.aiTutor);
    expectGuarded(
      () => container.read(accountDeletionRepositoryProvider),
      AppCapability.accountDeletion,
    );
  });
}
