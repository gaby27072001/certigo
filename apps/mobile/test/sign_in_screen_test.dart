import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/presentation/sign_in_screen.dart';
import 'package:certigo/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Tests d'interface de [SignInScreen] : formulaire e-mail (Se connecter /
/// Créer un compte) toujours présent, et boutons sociaux affichés uniquement
/// quand Entra est configuré.
///
/// On ne `pumpAndSettle` jamais : l'[AuroraBackground] anime en boucle et ne se
/// stabiliserait jamais.
void main() {
  Future<void> pumpSignIn(
    WidgetTester tester, {
    required FakeAuthGateway gateway,
    required FakeSessionStore store,
    FakeCredentialsGateway? credentials,
    bool configured = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(gateway),
          credentialsGatewayProvider.overrideWithValue(credentials ?? FakeCredentialsGateway()),
          sessionStoreProvider.overrideWithValue(store),
          authConfiguredProvider.overrideWithValue(configured),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: PrismTheme.light(), home: const SignInScreen()),
      ),
    );
    // Laisse la restauration différée se résoudre (aucune session → écran de
    // connexion), puis une frame courte de mise en page.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('présente le formulaire e-mail (Se connecter par défaut)', (tester) async {
    await pumpSignIn(tester, gateway: FakeAuthGateway(), store: FakeSessionStore());

    expect(find.text('Certigo'), findsOneWidget);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('password-field')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
    // Pas de champ « nom » en mode connexion.
    expect(find.byKey(const Key('name-field')), findsNothing);
  });

  testWidgets('avec Entra configuré, présente aussi les trois boutons sociaux', (tester) async {
    await pumpSignIn(tester, gateway: FakeAuthGateway(), store: FakeSessionStore());

    expect(find.byType(AuthProviderButton), findsNWidgets(3));
    expect(find.text('Continuer avec Microsoft'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Continuer avec Apple'), findsOneWidget);
  });

  testWidgets('sans Entra, les boutons sociaux disparaissent mais le formulaire reste', (
    tester,
  ) async {
    await pumpSignIn(
      tester,
      gateway: FakeAuthGateway(),
      store: FakeSessionStore(),
      configured: false,
    );

    expect(find.byType(AuthProviderButton), findsNothing);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
  });

  testWidgets('bascule vers « Créer un compte » affiche le champ nom', (tester) async {
    await pumpSignIn(tester, gateway: FakeAuthGateway(), store: FakeSessionStore());

    await tester.tap(find.byKey(const Key('toggle-mode')));
    await tester.pump();

    expect(find.byKey(const Key('name-field')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Créer un compte'), findsOneWidget);
  });

  testWidgets('le tap sur un fournisseur déclenche sa connexion', (tester) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: (AuthProvider provider) => AuthSession(accessToken: 'jeton', provider: provider),
    );
    final FakeSessionStore store = FakeSessionStore();
    await pumpSignIn(tester, gateway: gateway, store: store);

    final Finder google = find.text('Continuer avec Google');
    await tester.ensureVisible(google);
    await tester.pump();
    await tester.tap(google);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(gateway.signInCalls, <AuthProvider>[AuthProvider.google]);
    // La session a bien été persistée → l'app se rouvrira dessus.
    expect(store.writeCalls, 1);
  });

  testWidgets('une connexion e-mail valide appelle login et persiste la session', (tester) async {
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String email, String password) => AuthSession(
        accessToken: 'jeton',
        refreshToken: 'refresh',
        provider: AuthProvider.email,
        email: email,
      ),
    );
    final FakeSessionStore store = FakeSessionStore();
    await pumpSignIn(tester, gateway: FakeAuthGateway(), store: store, credentials: credentials);

    await tester.enterText(find.byKey(const Key('email-field')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('password-field')), 'password123');
    await tester.tap(find.byKey(const Key('email-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(credentials.loginCalls, <String>['a@b.com']);
    expect(store.writeCalls, 1);
  });

  testWidgets('un e-mail invalide bloque la soumission et affiche les erreurs', (tester) async {
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (_, __) => const AuthSession(accessToken: 'x'),
    );
    await pumpSignIn(
      tester,
      gateway: FakeAuthGateway(),
      store: FakeSessionStore(),
      credentials: credentials,
    );

    await tester.enterText(find.byKey(const Key('email-field')), 'pas-un-email');
    await tester.enterText(find.byKey(const Key('password-field')), 'court');
    await tester.tap(find.byKey(const Key('email-submit')));
    await tester.pump();

    expect(credentials.loginCalls, isEmpty);
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);
  });

  testWidgets('annulation d\'une connexion sociale affiche un message et réarme le bouton', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: (_) =>
          throw const AuthGatewayException('Connexion annulée.', cause: AuthFailureCause.cancelled),
    );
    await pumpSignIn(tester, gateway: gateway, store: FakeSessionStore());

    final Finder microsoft = find.text('Continuer avec Microsoft');
    await tester.ensureVisible(microsoft);
    await tester.pump();
    await tester.tap(microsoft);
    await tester.pump(); // AuthLoading
    await tester.pump(const Duration(milliseconds: 50)); // échec → carte persistante + réarmement

    expect(gateway.signInCalls, <AuthProvider>[AuthProvider.microsoft]);
    // Message d'annulation affiché dans la carte d'erreur persistante.
    expect(find.text('Connexion annulée.'), findsOneWidget);
    // Bouton réarmé : plus de spinner en cours.
    final AuthProviderButton button = tester.widget<AuthProviderButton>(
      find.ancestor(of: microsoft, matching: find.byType(AuthProviderButton)),
    );
    expect(button.loading, isFalse);
    expect(button.enabled, isTrue);
  });

  testWidgets('échec social → carte persistante et sélectionnable avec détail technique', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: (_) => throw const AuthGatewayException(
        'Fournisseur microsoft indisponible dans Entra External ID.',
        cause: AuthFailureCause.providerError,
        diagnostic: 'PlatformException code=access_denied msg=IdP refusé',
      ),
    );
    await pumpSignIn(tester, gateway: gateway, store: FakeSessionStore());

    final Finder microsoft = find.text('Continuer avec Microsoft');
    await tester.ensureVisible(microsoft);
    await tester.pump();
    await tester.tap(microsoft);
    await tester.pump(); // AuthLoading
    await tester.pump(const Duration(milliseconds: 50)); // échec → carte persistante

    // La carte d'erreur persistante est affichée, avec le message convivial ET
    // le détail technique brut, dans un SelectableText (copiable/capturable).
    final Finder card = find.byKey(const Key('auth-error'));
    expect(card, findsOneWidget);
    final Finder selectableFinder = find.descendant(
      of: card,
      matching: find.byType(SelectableText),
    );
    expect(selectableFinder, findsOneWidget);
    final SelectableText selectable = tester.widget<SelectableText>(selectableFinder);
    expect(selectable.data, contains('Fournisseur microsoft indisponible'));
    expect(selectable.data, contains('[technique] PlatformException code=access_denied'));

    // Persistance : le temps passe mais la carte reste (contrairement à un
    // SnackBar auto-disparaissant) → l'utilisateur peut la lire et la capturer.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('auth-error')), findsOneWidget);
  });

  testWidgets('pendant une connexion e-mail en cours, le bouton est désactivé', (tester) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLoginFuture: (_, __) => pending.future,
    );
    await pumpSignIn(
      tester,
      gateway: FakeAuthGateway(),
      store: FakeSessionStore(),
      credentials: credentials,
    );

    await tester.enterText(find.byKey(const Key('email-field')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('password-field')), 'password123');
    await tester.tap(find.byKey(const Key('email-submit')));
    await tester.pump(); // état AuthLoading + _emailSubmitting

    // Anti-double-clic : le bouton principal n'a plus de handler tant que busy.
    final FilledButton submit = tester.widget<FilledButton>(find.byKey(const Key('email-submit')));
    expect(submit.onPressed, isNull);
    expect(credentials.loginCalls, hasLength(1));

    // Débloque la future pour laisser le test se terminer proprement.
    pending.complete(const AuthSession(accessToken: 'jeton'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });
}
