import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('ReleaseProfile', () {
    test('private Alpha is complete and enables every mandatory Core capability', () {
      final ReleaseProfile profile = ReleaseProfile.privateAlpha;

      expect(profile.validate(), isEmpty);
      expect(profile.maxTesterAccounts, ReleaseProfile.privateAlphaTesterLimit);
      expect(profile.capabilities.keys.toSet(), AppCapability.values.toSet());
      for (final AppCapability capability in AppCapability.values.where(
        (AppCapability capability) => capability.alphaCore,
      )) {
        expect(
          profile.availabilityOf(capability),
          CapabilityAvailability.enabled,
          reason: capability.id,
        );
      }
    });

    test('full profile preserves enabled behavior for every capability', () {
      expect(ReleaseProfile.full.validate(), isEmpty);
      for (final AppCapability capability in AppCapability.values) {
        expect(ReleaseProfile.full.isEnabled(capability), isTrue, reason: capability.id);
      }
    });

    test('missing capability and missing Core both fail closed', () {
      final Map<AppCapability, CapabilityAvailability> incomplete =
          Map<AppCapability, CapabilityAvailability>.of(ReleaseProfile.privateAlpha.capabilities)
            ..remove(AppCapability.lessons);

      final ReleaseProfileResolution resolution = ReleaseProfile.fromDefinition(
        id: ReleaseProfileId.privateAlpha,
        maxTesterAccounts: ReleaseProfile.privateAlphaTesterLimit,
        capabilities: incomplete,
      );

      expect(resolution.isValid, isFalse);
      expect(resolution.issue?.code, 'missing-capability');
      expect(resolution.profile, same(ReleaseProfile.failClosed));
    });

    test('Core cannot be marked upcoming in the private Alpha', () {
      final Map<AppCapability, CapabilityAvailability> invalid =
          Map<AppCapability, CapabilityAvailability>.of(ReleaseProfile.privateAlpha.capabilities)
            ..[AppCapability.quizCorrection] = CapabilityAvailability.upcoming;

      final ReleaseProfileResolution resolution = ReleaseProfile.fromDefinition(
        id: ReleaseProfileId.privateAlpha,
        maxTesterAccounts: ReleaseProfile.privateAlphaTesterLimit,
        capabilities: invalid,
      );

      expect(resolution.isValid, isFalse);
      expect(resolution.issue?.code, 'alpha-core-not-enabled');
      expect(resolution.profile, same(ReleaseProfile.failClosed));
    });

    test('off, upcoming and enabled remain distinct migration-free states', () {
      expect(
        ReleaseProfile.privateAlpha.availabilityOf(AppCapability.publicRegistration),
        CapabilityAvailability.off,
      );
      expect(
        ReleaseProfile.privateAlpha.availabilityOf(AppCapability.socialFriends),
        CapabilityAvailability.upcoming,
      );
      expect(
        ReleaseProfile.full.availabilityOf(AppCapability.socialFriends),
        CapabilityAvailability.enabled,
      );
    });

    test('runtime policy preserves declared states and blocks destructive enablement', () {
      const CapabilityRuntimePolicy blocked = CapabilityRuntimePolicy(
        accountDeletionEnabled: false,
      );

      expect(
        blocked.availabilityOf(ReleaseProfile.privateAlpha, AppCapability.accountDeletion),
        CapabilityAvailability.upcoming,
      );
      expect(
        blocked.availabilityOf(ReleaseProfile.full, AppCapability.accountDeletion),
        CapabilityAvailability.off,
      );
      expect(
        blocked.availabilityOf(ReleaseProfile.full, AppCapability.socialFriends),
        CapabilityAvailability.enabled,
      );
    });
  });

  group('ReleaseProfile.resolve', () {
    test('accepts only the two explicit deployable profile identifiers', () {
      expect(ReleaseProfile.resolve('private-alpha').profile, same(ReleaseProfile.privateAlpha));
      expect(ReleaseProfile.resolve('full').profile, same(ReleaseProfile.full));
    });

    test('absent or malformed configuration resolves to fail-closed', () {
      for (final String value in <String>['', 'unknown', 'alpha']) {
        final ReleaseProfileResolution resolution = ReleaseProfile.resolve(value);
        expect(resolution.isValid, isFalse, reason: value);
        expect(resolution.profile, same(ReleaseProfile.failClosed), reason: value);
      }
    });
  });
}
