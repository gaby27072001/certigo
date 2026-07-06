import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/register_draft.dart';
import 'package:certigo/features/auth/presentation/register_email_screen.dart';
import 'package:certigo/features/auth/presentation/register_friends_screen.dart';
import 'package:certigo/features/auth/presentation/register_name_screen.dart';
import 'package:certigo/features/auth/presentation/register_password_screen.dart';
import 'package:certigo/features/auth/presentation/register_profile_created_screen.dart';
import 'package:certigo/features/auth/presentation/register_sync_contacts_screen.dart';
import 'package:certigo/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:certigo/features/onboarding/presentation/onboarding_common.dart' show SoonTag;

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Tests d'interface du flux d'inscription progressif (Partie 3). Chaque écran
/// est monté sous un petit [GoRouter] contenant TOUTES les routes register plus
/// des cibles stub (/home, /landing, /auth), de sorte que les navigations
/// réelles du flux (nom → e-mail → mot de passe → post-création) se résolvent.
///
/// On désactive les animations (via un [MediaQuery] injecté) pour que
/// [TypewriterText] affiche instantanément son texte complet et que les CTA
/// soient tappables sans `pumpAndSettle`.
void main() {
  Future<ProviderContainer> pumpFlow(
    WidgetTester tester, {
    required String initial,
    bool configured = true,
    FakeCredentialsGateway? credentials,
    FakeSessionStore? store,
    FakeAuthGateway? gateway,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(gateway ?? FakeAuthGateway()),
        credentialsGatewayProvider.overrideWithValue(credentials ?? FakeCredentialsGateway()),
        sessionStoreProvider.overrideWithValue(store ?? FakeSessionStore()),
        authConfiguredProvider.overrideWithValue(configured),
        authRequiredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: initial,
      routes: <RouteBase>[
        GoRoute(path: '/register/name', builder: (_, __) => const RegisterNameScreen()),
        GoRoute(path: '/register/email', builder: (_, __) => const RegisterEmailScreen()),
        GoRoute(path: '/register/password', builder: (_, __) => const RegisterPasswordScreen()),
        GoRoute(
          path: '/register/sync-contacts',
          builder: (_, __) => const RegisterSyncContactsScreen(),
        ),
        GoRoute(path: '/register/friends', builder: (_, __) => const RegisterFriendsScreen()),
        GoRoute(
          path: '/register/profile-created',
          builder: (_, __) => const RegisterProfileCreatedScreen(),
        ),
        GoRoute(path: '/home', builder: (_, __) => const _Stub('stub-home')),
        GoRoute(path: '/landing', builder: (_, __) => const _Stub('stub-landing')),
        GoRoute(path: '/auth', builder: (_, __) => const _Stub('stub-auth')),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    // Laisse la restauration différée (aucune session → Unauthenticated) et la
    // mise en page se résoudre.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    return container;
  }

  PrismButton cta(WidgetTester tester) => tester.widget<PrismButton>(find.byType(PrismButton));

  group('RegisterNameScreen', () {
    testWidgets('rend, grise le CTA tant que le prénom est vide puis navigue', (tester) async {
      await pumpFlow(tester, initial: '/register/name');

      expect(find.byKey(const Key('register-first-name')), findsOneWidget);
      // CTA désactivé au départ (prénom requis).
      expect(cta(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('register-first-name')), 'Alex');
      await tester.pump();
      expect(cta(tester).onPressed, isNotNull);

      await tester.tap(find.text('CONTINUER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // On atterrit sur l'écran e-mail (salutation personnalisée).
      expect(find.textContaining('Alex'), findsWidgets);
    });

    testWidgets('affiche les boutons sociaux seulement si Entra est configuré', (tester) async {
      await pumpFlow(tester, initial: '/register/name', configured: true);
      expect(find.byType(AuthProviderButton), findsNWidgets(3));

      await pumpFlow(tester, initial: '/register/name', configured: false);
      expect(find.byType(AuthProviderButton), findsNothing);
    });

    testWidgets('une réussite sociale authentifie et sort du flux vers /home', (tester) async {
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (provider) => AuthSession(accessToken: 'jeton', provider: provider),
      );
      final FakeSessionStore store = FakeSessionStore();
      await pumpFlow(tester, initial: '/register/name', gateway: gateway, store: store);

      await tester.tap(find.text('Continuer avec Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(gateway.signInCalls, <AuthProvider>[AuthProvider.google]);
      expect(find.text('stub-home'), findsOneWidget);
    });
  });

  group('RegisterEmailScreen', () {
    testWidgets('grise le CTA sur e-mail invalide, l\'active sur e-mail valide', (tester) async {
      final ProviderContainer c = await pumpFlow(tester, initial: '/register/email');
      c.read(registerDraftProvider.notifier).setName(firstName: 'Alex', lastName: '');
      await tester.pump();

      await tester.enterText(find.byKey(const Key('register-email')), 'pas-un-email');
      await tester.pump();
      expect(cta(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('register-email')), 'alex@certigo.io');
      await tester.pump();
      expect(cta(tester).onPressed, isNotNull);
    });

    testWidgets('propose une correction de domaine et l\'applique au tap', (tester) async {
      await pumpFlow(tester, initial: '/register/email');
      await tester.enterText(find.byKey(const Key('register-email')), 'alex@gmial.com');
      await tester.pump();

      expect(find.byKey(const Key('register-email-suggestion')), findsOneWidget);
      await tester.tap(find.byKey(const Key('register-email-suggestion')));
      await tester.pump();

      final TextField field = tester.widget<TextField>(find.byKey(const Key('register-email')));
      expect(field.controller!.text, 'alex@gmail.com');
    });
  });

  group('RegisterPasswordScreen — branchement backend réel', () {
    testWidgets('un mot de passe valide appelle registerWithEmail et enchaîne', (tester) async {
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onRegister: (String email, String password, String? name) => AuthSession(
          accessToken: 'jeton',
          refreshToken: 'refresh',
          provider: AuthProvider.email,
          email: email,
          displayName: name,
        ),
      );
      final FakeSessionStore store = FakeSessionStore();
      final ProviderContainer c = await pumpFlow(
        tester,
        initial: '/register/password',
        credentials: credentials,
        store: store,
      );
      c.read(registerDraftProvider.notifier).setName(firstName: 'Alex', lastName: 'Martin');
      c.read(registerDraftProvider.notifier).setEmail('new@certigo.io');
      await tester.pump();

      // CTA désactivé tant que le mot de passe est trop court.
      await tester.enterText(find.byKey(const Key('register-password')), 'court');
      await tester.pump();
      expect(cta(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('register-password')), 'password123');
      await tester.pump();
      expect(cta(tester).onPressed, isNotNull);

      await tester.tap(find.text('CONTINUER'));
      await tester.pump(); // AuthLoading + submitting
      await tester.pump(const Duration(milliseconds: 60)); // register résolu → Authenticated

      expect(credentials.registerCalls, <String>['new@certigo.io']);
      expect(store.writeCalls, 1);
      // On enchaîne sur l'écran post-création (contacts).
      expect(find.text('AUTORISER LES CONTACTS'), findsOneWidget);
    });

    testWidgets('un échec backend affiche un message et reste sur l\'écran', (tester) async {
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onRegister: (_, __, ___) => const AuthSession(accessToken: ''),
      );
      final ProviderContainer c = await pumpFlow(
        tester,
        initial: '/register/password',
        credentials: credentials,
      );
      c.read(registerDraftProvider.notifier).setEmail('new@certigo.io');
      await tester.pump();

      await tester.enterText(find.byKey(const Key('register-password')), 'password123');
      await tester.pump();
      await tester.tap(find.text('CONTINUER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Toujours sur l'écran de mot de passe (pas de navigation vers contacts).
      expect(find.byKey(const Key('register-password')), findsOneWidget);
      expect(find.text('AUTORISER LES CONTACTS'), findsNothing);
    });
  });

  group('Écrans post-création (placeholders)', () {
    testWidgets('SyncContacts affiche le tag « Bientôt » et les deux issues', (tester) async {
      await pumpFlow(tester, initial: '/register/sync-contacts');
      expect(find.byType(SoonTag), findsOneWidget);
      expect(find.text('CONTINUER SANS CONTACTS'), findsOneWidget);

      await tester.tap(find.text('AUTORISER LES CONTACTS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(ChoiceTile), findsWidgets); // écran amis
    });

    testWidgets('Friends liste des amis fictifs et met à jour le CTA', (tester) async {
      await pumpFlow(tester, initial: '/register/friends');
      expect(find.byType(SoonTag), findsOneWidget);
      expect(find.byType(ChoiceTile), findsNWidgets(5));
      expect(find.text('CONTINUER'), findsOneWidget);

      await tester.tap(find.byKey(const Key('register-friend-0')));
      await tester.pump();
      expect(find.text('AJOUTER 1 AMI'), findsOneWidget);

      await tester.tap(find.byKey(const Key('register-friend-1')));
      await tester.pump();
      expect(find.text('AJOUTER 2 AMIS'), findsOneWidget);

      await tester.tap(find.text('AJOUTER 2 AMIS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Écran de bienvenue atteint.
      expect(find.byType(MascotHero), findsOneWidget);
    });

    testWidgets('ProfileCreated salue par le prénom et remet le brouillon à zéro', (tester) async {
      final ProviderContainer c = await pumpFlow(tester, initial: '/register/profile-created');
      c.read(registerDraftProvider.notifier).setName(firstName: 'Alex', lastName: '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.textContaining('Bienvenue Alex'), findsWidgets);

      await tester.tap(find.text('CONTINUER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Brouillon réinitialisé et navigation vers l'accueil (le garde prendra le
      // relais en conditions réelles ; ici la cible stub confirme la navigation).
      expect(c.read(registerDraftProvider).firstName, isEmpty);
      expect(find.text('stub-home'), findsOneWidget);
    });
  });
}

/// Écran cible minimal pour prouver une navigation hors du flux register.
class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}
