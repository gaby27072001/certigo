import 'package:certigo/app/content/runtime_content_dependencies.dart';
import 'package:certigo/app/providers.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ApiClient api;

  setUp(() {
    api = ApiClient(
      baseUrl: 'https://example.test',
      tokenProvider: () async => null,
    );
  });

  test('runtime content stays off and preserves the online repository by default', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    expect(container.read(runtimeContentSyncEnabledProvider), isFalse);
    expect(container.read(lessonRepositoryProvider), isA<RemoteLessonRepository>());
  });

  test('flag off preserves the legacy offline lesson cache decorator', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        apiClientProvider.overrideWithValue(api),
        offlineStudyCacheEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(runtimeContentSyncEnabledProvider), isFalse);
    expect(container.read(lessonRepositoryProvider), isA<OfflineLessonRepository>());
  });
}
