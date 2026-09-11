import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:core/core.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/path/presentation/path_screen.dart';
import '../features/lesson/presentation/lesson_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/library/presentation/certification_chapters_screen.dart';
import '../features/library/presentation/vendor_catalog_screen.dart';
import '../features/library/presentation/vendor_certifications_screen.dart';
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
import '../features/auth/presentation/landing_screen.dart';
import '../features/auth/presentation/register_name_screen.dart';
import '../features/auth/presentation/register_email_screen.dart';
import '../features/auth/presentation/register_password_screen.dart';
import '../features/auth/presentation/register_profile_created_screen.dart';
import '../features/auth/presentation/splash_screen.dart' as auth;
import '../features/account_deletion/presentation/account_deletion_screen.dart';
import '../features/manager/application/manager_route_codec.dart';
import '../features/manager/presentation/manager_portal_screen.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/certification_screen.dart';
import '../features/onboarding/presentation/onboarding_common.dart';
import '../features/onboarding/presentation/splash_screen.dart' as onboarding;
import '../features/onboarding/presentation/welcome_screen.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';
import 'providers.dart';
import 'step_page.dart';

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
  static const String landing = '/landing'; // Luma-style opening hero (pre-auth)
  static const String auth = '/auth'; // sign-in (Microsoft / Google / Apple / e-mail)

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
  static const String accountDeletion = '/account/delete';
  static const String accountDeleted = '/account/deleted';
  static const String manager = '/enterprise';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Page Prism pour une étape hors coquille.
///
/// Sur **iOS** on renvoie un [CupertinoPage] : il installe la transition
/// horizontale native ET le détecteur de geste de retour par balayage depuis le
/// bord gauche. Le paramètre [begin] est alors ignoré (la transition Cupertino
/// est fixe).
///
/// Sur les **autres plateformes** on garde la transition Prism
/// ([CustomTransitionPage] avec fade + slide) : le mandat produit veut préserver
/// l'identité visuelle Prism sur Android, quitte à ne pas brancher le
/// « predictive back gesture » (à revoir dans une PR séparée si souhaité).
///
/// Le [context.canPop()] côté appelant reste la condition d'activation du
/// geste — c'est pourquoi les navigations d'entrée dans un sous-flux (register,
/// onboarding, explorations) doivent utiliser `context.push(...)` plutôt que
/// `.go(...)` pour empiler. Les écrans « en cours » (`/lesson`, `/quiz`,
/// `/exam`) restent atteints par `.go(...)` : la pile est vidée, le geste
/// devient naturellement inerte et rien n'est perdu silencieusement.
Page<void> _stepPage({
  required GoRouterState state,
  required Widget child,
  Offset begin = const Offset(0.06, 0),
}) {
  return stepPage(state: state, child: child, begin: begin);
}

/// The app router. Exposed as a provider so auth/session/onboarding guards can
/// react to state changes without rebuilding the app shell manually.
final routerProvider = Provider<GoRouter>((Ref ref) {
  // Garde de synchronisation : les constantes du garde d'auth (fichier feuille
  // testable) doivent rester alignées sur le table de routes et l'onboarding.
  // En debug, tout écart casse tôt plutôt que de laisser passer une régression.
  assert(
    Routes.splash == AuthShellRoutes.splash,
    'Routes.splash désynchronisé',
  );
  assert(
    Routes.landing == AuthShellRoutes.landing,
    'Routes.landing désynchronisé',
  );
  assert(Routes.auth == AuthShellRoutes.auth, 'Routes.auth désynchronisé');
  assert(Routes.home == AuthShellRoutes.home, 'Routes.home désynchronisé');
  assert(
    Routes.accountDeleted == AuthShellRoutes.accountDeleted,
    'Routes.accountDeleted désynchronisé',
  );
  assert(
    OnboardingRoutes.splash == AuthShellRoutes.onboardingSplash,
    'OnboardingRoutes.splash désynchronisé du garde d\'auth',
  );
  assert(
    OnboardingRoutes.all.every(AuthShellRoutes.startupPaths.contains) &&
        AuthShellRoutes.startupPaths.every(OnboardingRoutes.all.contains),
    'AuthShellRoutes.startupPaths désynchronisé de OnboardingRoutes.all',
  );

  // Bridge auth-state changes into a [Listenable] so GoRouter re-runs redirects
  // as soon as session restore / sign-in / sign-out happens.
  final OnboardingController onboardingCtrl = ref.read(
    onboardingControllerProvider,
  );
  final ValueNotifier<int> authRefresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, AuthState next) {
    authRefresh.value++;
  });
  ref.onDispose(authRefresh.dispose);

  final Listenable refresh = Listenable.merge(<Listenable>[
    authRefresh,
    onboardingCtrl,
  ]);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      if (!AppEnv.accountDeletionEnabled && state.matchedLocation == Routes.accountDeletion) {
        return Routes.profile;
      }
      final AuthState auth = ref.read(authControllerProvider);
      return resolveAuthRedirect(
        auth: auth,
        location: state.matchedLocation,
        onboardingCompleted: onboardingCtrl.completed,
      );
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
        path: Routes.landing,
        name: 'landing',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) => _stepPage(
          state: state,
          child: const LandingScreen(),
          begin: const Offset(0, 0.03),
        ),
      ),
      GoRoute(
        path: Routes.auth,
        name: 'auth',
        parentNavigatorKey: _rootKey,
        builder: (_, GoRouterState state) => SignInScreen(
          // Ouvert depuis la sheet « Commencer » avec ?emailOnly=1 : on masque
          // alors les boutons sociaux (déjà proposés par la sheet).
          emailOnly: state.uri.queryParameters['emailOnly'] == '1',
        ),
      ),
      GoRoute(
        path: Routes.accountDeletion,
        parentNavigatorKey: _rootKey,
        builder: (_, GoRouterState state) =>
            AccountDeletionScreen(expectedUserId: state.extra as String?),
      ),
      GoRoute(
        path: Routes.accountDeleted,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const AccountDeletionCompletedScreen(),
      ),
      if (AppEnv.managerPortalEnabled)
        GoRoute(
          path: '${Routes.manager}/:organizationId',
          name: 'manager',
          parentNavigatorKey: _rootKey,
          builder: (BuildContext context, GoRouterState state) => ManagerPortalScreen(
            organizationId: managerOrganizationIdFromUri(state.uri),
          ),
        ),

      // Real account creation: name → email → password → confirmation.
      GoRoute(
        path: AuthShellRoutes.registerName,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const RegisterNameScreen()),
      ),
      GoRoute(
        path: AuthShellRoutes.registerEmail,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const RegisterEmailScreen()),
      ),
      GoRoute(
        path: AuthShellRoutes.registerPassword,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const RegisterPasswordScreen()),
      ),
      GoRoute(
        path: AuthShellRoutes.registerProfileCreated,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) => _stepPage(
          state: state,
          child: const RegisterProfileCreatedScreen(),
          begin: const Offset(0, 0.03),
        ),
      ),

      // Honest startup flow: brief welcome → published certification → Home.
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
        path: OnboardingRoutes.certification,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, GoRouterState state) =>
            _stepPage(state: state, child: const CertificationScreen()),
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
                builder: (_, __) => const ActivePathScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.library,
                name: 'library',
                builder: (_, __) => const VendorCatalogScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'vendor/:vendorId',
                    name: 'library-vendor',
                    builder: (BuildContext context, GoRouterState state) {
                      final VendorBrand vendor = VendorBrandInfo.fromId(
                        state.pathParameters['vendorId'] ?? '',
                      );
                      return VendorCertificationsScreen(vendor: vendor);
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'cert/:trackId',
                        name: 'library-chapters',
                        builder: (BuildContext context, GoRouterState state) {
                          final String trackId = Uri.decodeComponent(
                            state.pathParameters['trackId'] ?? '',
                          );
                          return CertificationChaptersScreen(trackId: trackId);
                        },
                      ),
                    ],
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
            trackId: Uri.decodeComponent(state.pathParameters['trackId']!),
            lessonId: Uri.decodeComponent(state.pathParameters['lessonId']!),
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
            trackId: Uri.decodeComponent(state.pathParameters['trackId']!),
            lessonId: Uri.decodeComponent(state.pathParameters['lessonId']!),
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
class ActivePathScreen extends ConsumerWidget {
  const ActivePathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> activeTrack = ref.watch(activeTrackProvider);
    return activeTrack.when(
      data: (String? trackId) => trackId == null
          ? Scaffold(
              body: PrismStatusView(
                icon: Icons.school_outlined,
                title: 'Aucune certification sélectionnée',
                message: 'Choisis un parcours publié avant d\'ouvrir le programme.',
                actionLabel: 'Voir la bibliothèque',
                actionIcon: Icons.local_library_rounded,
                onAction: () => context.go(Routes.library),
              ),
            )
          : PathScreen(trackId: trackId),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace _) => Scaffold(
        body: PrismStatusView.error(
          message: 'Impossible de restaurer la certification sélectionnée.',
          onRetry: () => ref.invalidate(activeTrackProvider),
        ),
      ),
    );
  }
}
