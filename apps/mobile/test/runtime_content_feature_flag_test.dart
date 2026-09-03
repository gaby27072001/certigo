import 'package:certigo/app/capabilities/release_profile_provider.dart';
import 'package:certigo/app/content/runtime_content_providers.dart';
import 'package:certigo/app/providers.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ApiClient api;

  setUp(() {
    api = ApiClient(baseUrl: 'https://example.test', tokenProvider: () async => null);
  });

  for (final ReleaseProfile profile in <ReleaseProfile>[
    ReleaseProfile.privateAlpha,
    ReleaseProfile.full,
  ]) {
    test('${profile.id.configValue} keeps offline and versioned lesson content active', () {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          releaseProfileProvider.overrideWithValue(profile),
          apiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      expect(profile.isEnabled(AppCapability.offlineResilience), isTrue);
      expect(profile.isEnabled(AppCapability.versionedContent), isTrue);
      expect(container.read(lessonRepositoryProvider), isA<RuntimeContentLessonRepository>());
    });
  }

  test('fail-closed profile stops lesson service construction before API access', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[releaseProfileProvider.overrideWithValue(ReleaseProfile.failClosed)],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(lessonRepositoryProvider),
      throwsA(
        isA<CapabilityUnavailableException>().having(
          (CapabilityUnavailableException error) => error.capability,
          'capability',
          AppCapability.lessons,
        ),
      ),
    );
  });

  test('legacy cache and runtime-content provider overrides remain effective', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        releaseProfileProvider.overrideWithValue(ReleaseProfile.full),
        apiClientProvider.overrideWithValue(api),
        offlineStudyCacheEnabledProvider.overrideWithValue(false),
        runtimeContentSyncEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(lessonRepositoryProvider), isA<RemoteLessonRepository>());
  });

  test('runtime cache namespace includes the normalized API base path', () {
    final String first = runtimeContentSpaceScopeFor(
      flavor: 'staging',
      apiBaseUri: Uri.parse('https://api.example.test/api-a/'),
    );
    final String equivalent = runtimeContentSpaceScopeFor(
      flavor: 'staging',
      apiBaseUri: Uri.parse('https://api.example.test/api-a'),
    );
    final String second = runtimeContentSpaceScopeFor(
      flavor: 'staging',
      apiBaseUri: Uri.parse('https://api.example.test/api-b'),
    );

    expect(first, equivalent);
    expect(first, isNot(second));
  });
}
