import '../../app/router.dart';

/// Exact allow-list: never hand server-provided URLs to a browser or router.
String? notificationDestination(String deeplink) => switch (deeplink) {
      'certigo://home' => Routes.home,
      // The home coach resolves the next lesson from the current server path.
      'certigo://lesson/next' => Routes.home,
      'certigo://quests' => Routes.quests,
      'certigo://league' => Routes.leaderboard,
      _ => null,
    };
