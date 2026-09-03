/// Lifecycle of a product capability in a release profile.
///
/// The order is intentional: a capability can move from [off] to [upcoming] to
/// [enabled] without changing its route, provider, model, or persistence shape.
enum CapabilityAvailability {
  off,
  upcoming,
  enabled;

  bool get isOff => this == CapabilityAvailability.off;
  bool get isUpcoming => this == CapabilityAvailability.upcoming;
  bool get isEnabled => this == CapabilityAvailability.enabled;
  bool get isVisible => this != CapabilityAvailability.off;
}

/// Typed capability catalog shared by release profiles.
///
/// Alpha Core capabilities are marked explicitly so profile validation can
/// reject any private-alpha definition that would ship an incomplete core.
enum AppCapability {
  authentication('authentication', alphaCore: true),
  certificationCatalog('certification-catalog', alphaCore: true),
  learningPath('learning-path', alphaCore: true),
  lessons('lessons', alphaCore: true),
  quizCorrection('quiz-correction', alphaCore: true),
  progressionReadinessXp('progression-readiness-xp', alphaCore: true),
  offlineResilience('offline-resilience', alphaCore: true),
  versionedContent('versioned-content', alphaCore: true),
  adaptiveRecommendations('adaptive-recommendations'),
  achievements('achievements'),
  seasons('seasons'),
  quests('quests'),
  shop('shop'),
  mockExam('mock-exam'),
  studyReminders('study-reminders'),
  publicRegistration('public-registration'),
  accountDeletion('account-deletion'),
  socialLeague('social-league'),
  socialFriends('social-friends'),
  socialSharing('social-sharing'),
  aiTutor('ai-tutor'),
  managerExperience('manager-experience'),
  organizationManagement('organization-management'),
  enterpriseSsoScim('enterprise-sso-scim'),
  vivaIntegration('viva-integration'),
  privateEnterpriseContent('private-enterprise-content'),
  portableAchievements('portable-achievements'),
  universalLinks('universal-links');

  const AppCapability(this.id, {this.alphaCore = false});

  final String id;
  final bool alphaCore;

  static AppCapability? fromId(String id) {
    for (final AppCapability capability in values) {
      if (capability.id == id) return capability;
    }
    return null;
  }
}

enum ReleaseProfileId {
  privateAlpha('private-alpha'),
  full('full'),
  failClosed('fail-closed');

  const ReleaseProfileId(this.configValue);

  final String configValue;
}

/// Immutable, complete release configuration.
///
/// Missing entries always resolve to [CapabilityAvailability.off]. Runtime
/// selection goes through [resolve], which returns [failClosed] for absent or
/// malformed configuration rather than guessing a permissive default.
class ReleaseProfile {
  const ReleaseProfile._({
    required this.id,
    required this.maxTesterAccounts,
    required this.capabilities,
  });

  static const int privateAlphaTesterLimit = 5;

  static const ReleaseProfile privateAlpha = ReleaseProfile._(
    id: ReleaseProfileId.privateAlpha,
    maxTesterAccounts: privateAlphaTesterLimit,
    capabilities: <AppCapability, CapabilityAvailability>{
      AppCapability.authentication: CapabilityAvailability.enabled,
      AppCapability.certificationCatalog: CapabilityAvailability.enabled,
      AppCapability.learningPath: CapabilityAvailability.enabled,
      AppCapability.lessons: CapabilityAvailability.enabled,
      AppCapability.quizCorrection: CapabilityAvailability.enabled,
      AppCapability.progressionReadinessXp: CapabilityAvailability.enabled,
      AppCapability.offlineResilience: CapabilityAvailability.enabled,
      AppCapability.versionedContent: CapabilityAvailability.enabled,
      AppCapability.adaptiveRecommendations: CapabilityAvailability.enabled,
      AppCapability.achievements: CapabilityAvailability.enabled,
      AppCapability.seasons: CapabilityAvailability.enabled,
      AppCapability.quests: CapabilityAvailability.enabled,
      AppCapability.shop: CapabilityAvailability.enabled,
      AppCapability.mockExam: CapabilityAvailability.enabled,
      AppCapability.studyReminders: CapabilityAvailability.enabled,
      AppCapability.publicRegistration: CapabilityAvailability.off,
      AppCapability.accountDeletion: CapabilityAvailability.upcoming,
      AppCapability.socialLeague: CapabilityAvailability.upcoming,
      AppCapability.socialFriends: CapabilityAvailability.upcoming,
      AppCapability.socialSharing: CapabilityAvailability.upcoming,
      AppCapability.aiTutor: CapabilityAvailability.upcoming,
      AppCapability.managerExperience: CapabilityAvailability.off,
      AppCapability.organizationManagement: CapabilityAvailability.off,
      AppCapability.enterpriseSsoScim: CapabilityAvailability.off,
      AppCapability.vivaIntegration: CapabilityAvailability.off,
      AppCapability.privateEnterpriseContent: CapabilityAvailability.off,
      AppCapability.portableAchievements: CapabilityAvailability.off,
      AppCapability.universalLinks: CapabilityAvailability.off,
    },
  );

  static const ReleaseProfile full = ReleaseProfile._(
    id: ReleaseProfileId.full,
    maxTesterAccounts: null,
    capabilities: <AppCapability, CapabilityAvailability>{
      AppCapability.authentication: CapabilityAvailability.enabled,
      AppCapability.certificationCatalog: CapabilityAvailability.enabled,
      AppCapability.learningPath: CapabilityAvailability.enabled,
      AppCapability.lessons: CapabilityAvailability.enabled,
      AppCapability.quizCorrection: CapabilityAvailability.enabled,
      AppCapability.progressionReadinessXp: CapabilityAvailability.enabled,
      AppCapability.offlineResilience: CapabilityAvailability.enabled,
      AppCapability.versionedContent: CapabilityAvailability.enabled,
      AppCapability.adaptiveRecommendations: CapabilityAvailability.enabled,
      AppCapability.achievements: CapabilityAvailability.enabled,
      AppCapability.seasons: CapabilityAvailability.enabled,
      AppCapability.quests: CapabilityAvailability.enabled,
      AppCapability.shop: CapabilityAvailability.enabled,
      AppCapability.mockExam: CapabilityAvailability.enabled,
      AppCapability.studyReminders: CapabilityAvailability.enabled,
      AppCapability.publicRegistration: CapabilityAvailability.enabled,
      AppCapability.accountDeletion: CapabilityAvailability.enabled,
      AppCapability.socialLeague: CapabilityAvailability.enabled,
      AppCapability.socialFriends: CapabilityAvailability.enabled,
      AppCapability.socialSharing: CapabilityAvailability.enabled,
      AppCapability.aiTutor: CapabilityAvailability.enabled,
      AppCapability.managerExperience: CapabilityAvailability.enabled,
      AppCapability.organizationManagement: CapabilityAvailability.enabled,
      AppCapability.enterpriseSsoScim: CapabilityAvailability.enabled,
      AppCapability.vivaIntegration: CapabilityAvailability.enabled,
      AppCapability.privateEnterpriseContent: CapabilityAvailability.enabled,
      AppCapability.portableAchievements: CapabilityAvailability.enabled,
      AppCapability.universalLinks: CapabilityAvailability.enabled,
    },
  );

  static const ReleaseProfile failClosed = ReleaseProfile._(
    id: ReleaseProfileId.failClosed,
    maxTesterAccounts: 0,
    capabilities: <AppCapability, CapabilityAvailability>{
      AppCapability.authentication: CapabilityAvailability.off,
      AppCapability.certificationCatalog: CapabilityAvailability.off,
      AppCapability.learningPath: CapabilityAvailability.off,
      AppCapability.lessons: CapabilityAvailability.off,
      AppCapability.quizCorrection: CapabilityAvailability.off,
      AppCapability.progressionReadinessXp: CapabilityAvailability.off,
      AppCapability.offlineResilience: CapabilityAvailability.off,
      AppCapability.versionedContent: CapabilityAvailability.off,
      AppCapability.adaptiveRecommendations: CapabilityAvailability.off,
      AppCapability.achievements: CapabilityAvailability.off,
      AppCapability.seasons: CapabilityAvailability.off,
      AppCapability.quests: CapabilityAvailability.off,
      AppCapability.shop: CapabilityAvailability.off,
      AppCapability.mockExam: CapabilityAvailability.off,
      AppCapability.studyReminders: CapabilityAvailability.off,
      AppCapability.publicRegistration: CapabilityAvailability.off,
      AppCapability.accountDeletion: CapabilityAvailability.off,
      AppCapability.socialLeague: CapabilityAvailability.off,
      AppCapability.socialFriends: CapabilityAvailability.off,
      AppCapability.socialSharing: CapabilityAvailability.off,
      AppCapability.aiTutor: CapabilityAvailability.off,
      AppCapability.managerExperience: CapabilityAvailability.off,
      AppCapability.organizationManagement: CapabilityAvailability.off,
      AppCapability.enterpriseSsoScim: CapabilityAvailability.off,
      AppCapability.vivaIntegration: CapabilityAvailability.off,
      AppCapability.privateEnterpriseContent: CapabilityAvailability.off,
      AppCapability.portableAchievements: CapabilityAvailability.off,
      AppCapability.universalLinks: CapabilityAvailability.off,
    },
  );

  final ReleaseProfileId id;

  /// UX contract only. Backend admission enforcement is intentionally separate.
  final int? maxTesterAccounts;

  final Map<AppCapability, CapabilityAvailability> capabilities;

  bool get isPrivateAlpha => id == ReleaseProfileId.privateAlpha;

  CapabilityAvailability availabilityOf(AppCapability capability) =>
      capabilities[capability] ?? CapabilityAvailability.off;

  bool isEnabled(AppCapability capability) => availabilityOf(capability).isEnabled;

  List<ReleaseProfileIssue> validate() {
    final List<ReleaseProfileIssue> issues = <ReleaseProfileIssue>[];
    for (final AppCapability capability in AppCapability.values) {
      if (!capabilities.containsKey(capability)) {
        issues.add(
          ReleaseProfileIssue('missing-capability', 'Missing capability "${capability.id}".'),
        );
      }
    }
    if (id == ReleaseProfileId.privateAlpha) {
      if (maxTesterAccounts != privateAlphaTesterLimit) {
        issues.add(
          const ReleaseProfileIssue(
            'invalid-alpha-audience',
            'The private alpha must declare exactly five tester accounts.',
          ),
        );
      }
      for (final AppCapability capability in AppCapability.values) {
        if (capability.alphaCore && availabilityOf(capability) != CapabilityAvailability.enabled) {
          issues.add(
            ReleaseProfileIssue(
              'alpha-core-not-enabled',
              'Alpha Core capability "${capability.id}" must be enabled.',
            ),
          );
        }
      }
    }
    if (id == ReleaseProfileId.full) {
      for (final AppCapability capability in AppCapability.values) {
        if (availabilityOf(capability) != CapabilityAvailability.enabled) {
          issues.add(
            ReleaseProfileIssue(
              'full-capability-not-enabled',
              'Full profile capability "${capability.id}" must be enabled.',
            ),
          );
        }
      }
    }
    return issues;
  }

  static ReleaseProfileResolution resolve(String rawValue) {
    final String value = rawValue.trim().toLowerCase();
    if (value.isEmpty) {
      return ReleaseProfileResolution.invalid(
        const ReleaseProfileIssue(
          'missing-release-profile',
          'CERTIGO_RELEASE_PROFILE is required.',
        ),
      );
    }
    final ReleaseProfile? profile = switch (value) {
      'private-alpha' => privateAlpha,
      'full' => full,
      _ => null,
    };
    if (profile == null) {
      return ReleaseProfileResolution.invalid(
        ReleaseProfileIssue('unknown-release-profile', 'Unknown CERTIGO_RELEASE_PROFILE "$value".'),
      );
    }
    final List<ReleaseProfileIssue> issues = profile.validate();
    return issues.isEmpty
        ? ReleaseProfileResolution.valid(profile)
        : ReleaseProfileResolution.invalid(issues.first);
  }

  /// Validates a typed definition supplied by tests or future contract loaders.
  ///
  /// Invalid definitions resolve to [failClosed], including missing Core entries.
  static ReleaseProfileResolution fromDefinition({
    required ReleaseProfileId id,
    required int? maxTesterAccounts,
    required Map<AppCapability, CapabilityAvailability> capabilities,
  }) {
    final ReleaseProfile profile = ReleaseProfile._(
      id: id,
      maxTesterAccounts: maxTesterAccounts,
      capabilities: Map<AppCapability, CapabilityAvailability>.unmodifiable(capabilities),
    );
    final List<ReleaseProfileIssue> issues = profile.validate();
    return issues.isEmpty
        ? ReleaseProfileResolution.valid(profile)
        : ReleaseProfileResolution.invalid(issues.first);
  }
}

/// Operational safety policy applied after a release profile is selected.
///
/// Release profiles describe the intended product surface. Independent
/// destructive-operation gates remain fail-closed until their operational
/// prerequisites have passed, without changing the profile or its routes.
class CapabilityRuntimePolicy {
  const CapabilityRuntimePolicy({required this.accountDeletionEnabled});

  static const CapabilityRuntimePolicy permissive = CapabilityRuntimePolicy(
    accountDeletionEnabled: true,
  );

  final bool accountDeletionEnabled;

  CapabilityAvailability availabilityOf(ReleaseProfile profile, AppCapability capability) {
    final CapabilityAvailability declared = profile.availabilityOf(capability);
    if (!declared.isEnabled) return declared;
    if (capability == AppCapability.accountDeletion && !accountDeletionEnabled) {
      return CapabilityAvailability.off;
    }
    return declared;
  }
}

class ReleaseProfileIssue {
  const ReleaseProfileIssue(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class ReleaseProfileResolution {
  const ReleaseProfileResolution.valid(this.profile) : issue = null;

  const ReleaseProfileResolution._invalid(this.issue) : profile = ReleaseProfile.failClosed;

  factory ReleaseProfileResolution.invalid(ReleaseProfileIssue issue) =>
      ReleaseProfileResolution._invalid(issue);

  final ReleaseProfile profile;
  final ReleaseProfileIssue? issue;

  bool get isValid => issue == null;
}
