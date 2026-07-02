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
import '../features/library/presentation/library_screen.dart';
import '../features/achievements/presentation/achievements_screen.dart';
import '../features/seasons/presentation/seasons_screen.dart';
import '../features/quests/presentation/quests_screen.dart';
import '../features/shop/presentation/shop_screen.dart';
import '../features/friends/presentation/friends_screen.dart';
import '../features/exam/presentation/exam_screen.dart';
import '../features/share/presentation/daily_share_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/splash_screen.dart' as auth;
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/birth_year_screen.dart';
import '../features/onboarding/presentation/goal_screen.dart';
import '../features/onboarding/presentation/domains_screen.dart';
import '../features/onboarding/presentation/level_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_common.dart';
import '../features/onboarding/presentation/promise_screen.dart';
import '../features/onboarding/presentation/reasons_screen.dart';
import '../features/onboarding/presentation/routine_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart' as onboarding;
import '../features/onboarding/presentation/start_choice_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import 'app_shell.dart';
import 'providers.dart';

/// Centralized, named route table. Using constants avoids stringly-typed
/// navigation scattered across the codebase.
abstract class Routes {
  static const String home = '/home';
  static const String path = '/path';
  static const String library = '/library';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';

  /// Auth flows (outside the shell, on the root navigator).
  static const String splash = '/splash'; // session restore in progress
  static const String auth = '/auth'; // sign-in (Microsoft / Google / Apple)

  /// Full-screen (outside the shell) flows.
  static const String lesson = '/lesson'; // /lesson/:trackId/:lessonId
  static const String quiz = '/quiz'; // /quiz/:trackId/:lessonId

  /// "Explore" destinations presented above the shell (no bottom nav).
  static const String achievements = '/achievements';
  static const String seasons = '/seasons';
  static const String quests = '/quests';
  static const String shop = '/shop';
  static const String friends = '/friends';
  static const String exam = '/exam';
  static const String dailyShare = '/share-daily';
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
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The app router. Exposed as a provider so auth/session/onboarding guards can
/// react to state changes without rebuilding the app shell manually.
final routerProvider = Provider<GoRouter>((Ref ref) {
  // Bridge auth-state changes into a [Listenable] so GoRouter re-runs redirects
  // as soon as session restore / sign-in / sign-out happens.
  final ValueNotifier<int> authRefresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, __) => authRefresh.value++);
  ref.onDispose(authRefresh.dispose);

  final OnboardingController onboardingCtrl = ref.read(
    onboardingControllerProvider,
  );
  final Listenable refresh = Listenable.merge(<Listenable>[
    authRefresh,
    onboardingCtrl,
  ]);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState auth = ref.read(authControllerProvider);
      final String loc = state.matchedLocation;
      final bool atAuthSplash = loc == Routes.splash;
      final bool atAuth = loc == Routes.auth;
      final bool atOnboarding = OnboardingRoutes.isStartup(loc);

      String? resolve() {
        // Restoring session: stay on auth splash.
        if (auth is AuthLoading) {
          return atAuthSplash ? null : Routes.splash;
        }
        // Not authenticated: force sign-in.
        if (auth is Unauthenticated) {
          return atAuth ? null : Routes.auth;
        }
        // Authenticated: never remain on auth surfaces.
        if (atAuthSplash || atAuth) {
          return onboardingCtrl.completed ? Routes.home : OnboardingRoutes.splash;
        }
        // Authenticated but onboarding not completed: force startup flow.
        if (!onboardingCtrl.completed) {
          return atOnboarding ? null : OnboardingRoutes.splash;
        }
        // Completed onboarding: startup screens should not be reachable.
        if (atOnboarding) return Routes.home;
        return null;
      }

      final String? target = resolve();
      final String targetLabel = target ?? 'stay';
      debugPrint(
        '[LOGIN-DBG] redirect: auth=${auth.runtimeType} loc=$loc -> $targetLabel',
      );
      return target;
    },
    routes: <RouteBase>[
      // Auth flows, above the shell (no bottom nav).
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const auth.SplashScreen(),
      ),
      GoRoute(
        path: Routes.auth,
        name: 'auth',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SignInScreen(),
      ),

      // Onboarding startup flow (full-screen, above the shell).
      GoRoute(
        path: OnboardingRoutes.splash,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) => _stepPage(
          state: state,
          child: const onboarding.SplashScreen(),
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
        path: OnboardingRoutes.domains,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const DomainsScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.level,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const LevelScreen()),
      ),
      GoRoute(
        path: OnboardingRoutes.goal,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) => _stepPage(state: state, child: const GoalScreen()),
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
      GoRoute(
        path: OnboardingRoutes.birthYear,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const BirthYearScreen()),
      ),
      // Bottom-nav shell: persistent state per tab via StatefulShellRoute.
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) {
          return AppShell(shell: shell);
        },
        branches: <StatefulShellBranch>[
          // Primary tab: Accueil (home) is the main entry surface.
          StatefulShellBranch(
            navigatorKey: _shellKey,
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
                path: Routes.path,
                name: 'path',
                builder: (_, __) => const _ActivePathScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.library,
                name: 'library',
                builder: (_, __) => const LibraryScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'domain/:id',
                    name: 'library-domain',
                    builder: (BuildContext context, GoRouterState state) {
                      final String id = state.pathParameters['id'] ?? '';
                      return Scaffold(
                        appBar: AppBar(title: Text(id)),
                        body: ListView(
                          children: <Widget>[
                            const SizedBox(height: 48),
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 72,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                'Contenu à venir pour ce domaine',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            const SizedBox(height: 48),
                          ],
                        ),
                      );
                    },
                  ),
                ],
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
      GoRoute(
        path: Routes.achievements,
        name: 'achievements',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: const AchievementsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.seasons,
        name: 'seasons',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: const SeasonsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.quests,
        name: 'quests',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: const QuestsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.shop,
        name: 'shop',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: const ShopScreen(),
        ),
      ),
      GoRoute(
        path: Routes.friends,
        name: 'friends',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: const FriendsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.exam,
        name: 'exam',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: const ExamScreen(),
        ),
      ),
      GoRoute(
        path: Routes.dailyShare,
        name: 'daily-share',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _stepPage(
          state: state,
          begin: const Offset(0, 0.04),
          child: const DailyShareScreen(),
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
