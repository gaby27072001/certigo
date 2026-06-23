import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/path/presentation/path_screen.dart';
import '../features/lesson/presentation/lesson_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/goal_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_common.dart';
import '../features/onboarding/presentation/promise_screen.dart';
import '../features/onboarding/presentation/reasons_screen.dart';
import '../features/onboarding/presentation/routine_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/onboarding/presentation/start_choice_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import 'app_shell.dart';

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

CustomTransitionPage<void> _stepPage({
  required GoRouterState state,
  required Widget child,
  Offset begin = const Offset(0.06, 0),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: PrismMotion.base,
    reverseTransitionDuration: PrismMotion.fast,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: PrismMotion.decelerate,
        reverseCurve: PrismMotion.standard,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The app router. Exposed as a provider so auth/redirect logic can later watch
/// session state and guard routes without rebuilding the widget tree manually.
final routerProvider = Provider<GoRouter>((Ref ref) {
  final OnboardingController onboarding = ref.read(onboardingControllerProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.path,
    refreshListenable: onboarding,
    // Gate the app behind the startup flow: an un-onboarded learner is funnelled
    // to the splash/welcome wizard; once finished they can no longer land back
    // on a startup screen. Lesson/quiz and shell tabs stay reachable afterwards.
    redirect: (BuildContext context, GoRouterState state) {
      final String loc = state.matchedLocation;
      final bool startup = OnboardingRoutes.isStartup(loc);
      if (!onboarding.completed) {
        return startup ? null : OnboardingRoutes.splash;
      }
      if (startup) return Routes.path;
      return null;
    },
    routes: <RouteBase>[
      // ---- Startup flow (full-screen, above the shell) --------------------
      GoRoute(
        path: OnboardingRoutes.splash,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) => _stepPage(
          state: state,
          child: const SplashScreen(),
          begin: const Offset(0, 0.03),
        ),
      ),
      GoRoute(
        path: OnboardingRoutes.welcome,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const WelcomeScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.start,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const StartChoiceScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.reasons,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const ReasonsScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.goal,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const GoalScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.routine,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const RoutineScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.promise,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const PromiseScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.login,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) => _stepPage(
          state: state,
          child: const LoginScreen(),
          begin: const Offset(0.03, 0),
        ),
      ),

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
                builder: (_, __) => const PathScreen(trackId: 'az-900'),
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
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: LessonScreen(
            trackId: state.pathParameters['trackId']!,
            lessonId: state.pathParameters['lessonId']!,
          ),
        ),
      ),
      GoRoute(
        path: '${Routes.quiz}/:trackId/:lessonId',
        name: 'quiz',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: QuizScreen(
            trackId: state.pathParameters['trackId']!,
            lessonId: state.pathParameters['lessonId']!,
          ),
        ),
      ),
    ],
  );
});
