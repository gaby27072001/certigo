import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/path/presentation/path_screen.dart';
import '../features/lesson/presentation/lesson_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import 'app_shell.dart';
import 'providers.dart';

/// Centralized, named route table. Using constants avoids stringly-typed
/// navigation scattered across the codebase.
abstract class Routes {
  static const String home = '/home';
  static const String path = '/path';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';

  /// Full-screen (outside the shell) flows.
  static const String lesson = '/lesson'; // /lesson/:trackId/:lessonId
  static const String quiz = '/quiz'; // /quiz/:trackId/:lessonId
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// The app router. Exposed as a provider so auth/redirect logic can later watch
/// session state and guard routes without rebuilding the widget tree manually.
final routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.path,
    routes: <RouteBase>[
      // Bottom-nav shell: persistent state per tab via StatefulShellRoute.
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) {
          return AppShell(shell: shell);
        },
        branches: <StatefulShellBranch>[
          // Primary tab: the Duolingo-style learning journey is the app's
          // home surface, so it leads the shell and is the initial location.
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: <RouteBase>[
              GoRoute(
                path: Routes.path,
                name: 'path',
                builder: (_, __) => const _ActivePathScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                name: 'home',
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.leaderboard,
                name: 'leaderboard',
                builder: (_, __) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.profile,
                name: 'profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Immersive flows presented above the shell (no bottom nav).
      GoRoute(
        path: '${Routes.lesson}/:trackId/:lessonId',
        name: 'lesson',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) => LessonScreen(
          trackId: state.pathParameters['trackId']!,
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
      GoRoute(
        path: '${Routes.quiz}/:trackId/:lessonId',
        name: 'quiz',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) => QuizScreen(
          trackId: state.pathParameters['trackId']!,
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
    ],
  );
});

/// Hosts the Path screen for whichever certification the learner has selected
/// in the course picker, so switching tracks re-points the primary tab without
/// touching the route table. The Path screen itself stays trackId-driven (and
/// directly constructible in tests).
class _ActivePathScreen extends ConsumerWidget {
  const _ActivePathScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String trackId = ref.watch(activeTrackProvider);
    return PathScreen(trackId: trackId);
  }
}
