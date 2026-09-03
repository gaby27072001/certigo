import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-Core screens, routes and providers remain present', () {
    const List<String> preservedScreens = <String>[
      'lib/features/leaderboard/presentation/leaderboard_screen.dart',
      'lib/features/friends/presentation/friends_screen.dart',
      'lib/features/share/presentation/daily_share_screen.dart',
      'lib/features/tutor/presentation/tutor_sheet.dart',
      'lib/features/account_deletion/presentation/account_deletion_screen.dart',
      'lib/features/achievements/presentation/achievements_screen.dart',
      'lib/features/seasons/presentation/seasons_screen.dart',
      'lib/features/quests/presentation/quests_screen.dart',
      'lib/features/shop/presentation/shop_screen.dart',
    ];
    for (final String path in preservedScreens) {
      expect(File(path).existsSync(), isTrue, reason: '$path must remain additive');
    }

    final String routes = File('lib/app/route_paths.dart').readAsStringSync();
    for (final String route in <String>[
      'leaderboard',
      'friends',
      'dailyShare',
      'accountDeletion',
      'achievements',
      'seasons',
      'quests',
      'shop',
    ]) {
      expect(routes, contains('static const String $route'), reason: route);
    }

    final String providers = File('lib/app/providers.dart').readAsStringSync();
    for (final String provider in <String>[
      'leaderboardRepositoryProvider',
      'friendRepositoryProvider',
      'shareCardRepositoryProvider',
      'tutorRepositoryProvider',
      'accountDeletionRepositoryProvider',
      'offlineStudyCacheEnabledProvider',
    ]) {
      expect(providers, contains('final $provider'), reason: provider);
    }

    final String contentProviders = File(
      'lib/app/content/runtime_content_dependencies.dart',
    ).readAsStringSync();
    expect(contentProviders, contains('final runtimeContentSyncEnabledProvider'));

    final String bootstrap = File('lib/bootstrap/bootstrap.dart').readAsStringSync();
    expect(
      bootstrap,
      contains(
        'capabilityRuntimePolicyProvider.overrideWithValue(AppEnv.capabilityRuntimePolicy)',
      ),
    );
  });
}
