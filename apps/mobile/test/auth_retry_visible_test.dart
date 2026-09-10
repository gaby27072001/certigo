import 'dart:async';

import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Ce que l'utilisateur voit **pendant** la reprise de connexion.
///
/// Le correctif précédent a rendu cet écran persistant pendant `AuthLoading` ;
/// la reprise allonge cet état. Sans avis visible, l'attente d'un démarrage à
/// froid serait suivie d'une seconde attente identique et muette — un indicateur
/// qui tourne sans changer cesse d'informer, et c'est là que l'utilisateur
/// appuie une seconde fois. Ces tests exercent donc la **fenêtre** de reprise,
/// pas seulement son issue.
void main() {
  Future<void> pumpSignIn(WidgetTester tester, FakeCredentialsGateway credentials) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(FakeAuthGateway()),
          credentialsGatewayProvider.overrideWithValue(credentials),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(true),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: PrismTheme.light(), home: const SignInScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('email-field')), 'qa@certigo.co');
    await tester.enterText(find.byKey(const Key('password-field')), 'Audit123!');
    await tester.tap(find.byKey(const Key('email-submit')));
    await tester.pump();
  }

  const AuthGatewayException serveurLent = AuthGatewayException(
    'Le serveur met trop de temps à répondre. Réessayez dans un instant.',
    cause: AuthFailureCause.timeout,
  );

  final Finder avis = find.byKey(const Key('email-retry-notice'));

  testWidgets('l\'avis de reprise est visible PENDANT la 2e tentative', (
    WidgetTester tester,
  ) async {
    // Les DEUX tentatives sont maintenues en vol pour observer chaque fenêtre :
    // une future d'erreur immédiate ferait échouer la 1re avant la 1re frame,
    // et l'on mesurerait alors la reprise en croyant mesurer l'attente initiale.
    final Completer<AuthSession> premiere = Completer<AuthSession>();
    final Completer<AuthSession> seconde = Completer<AuthSession>();
    int appels = 0;
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLoginFuture: (String email, String _) {
        appels++;
        return appels == 1 ? premiere.future : seconde.future;
      },
    );
    await pumpSignIn(tester, credentials);

    expect(avis, findsNothing, reason: 'rien avant la soumission');
    await submit(tester);

    // FENÊTRE 1 — première tentative en vol : on attend, sans annoncer de reprise.
    expect(appels, 1);
    expect(avis, findsNothing, reason: 'pas de reprise pendant le 1er essai');

    premiere.completeError(serveurLent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // FENÊTRE 2 — la reprise est en vol : c'est ici que l'écran doit parler.
    expect(appels, 2);
    expect(
      avis,
      findsOneWidget,
      reason: 'sans cet avis, l\'écran serait muet pendant les deux attentes',
    );
    expect(find.text('Le serveur démarre, on réessaie…'), findsOneWidget);

    // L'écran est toujours là — le garde ne l'a pas éjecté pendant AuthLoading.
    expect(find.byKey(const Key('email-submit')), findsOneWidget);

    seconde.complete(
      const AuthSession(accessToken: 'jeton', provider: AuthProvider.email, email: 'qa@certigo.co'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('l\'avis disparaît quand la reprise réussit', (WidgetTester tester) async {
    int appels = 0;
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String email, String _) {
        appels++;
        if (appels == 1) throw serveurLent;
        return AuthSession(accessToken: 'jeton', provider: AuthProvider.email, email: email);
      },
    );
    await pumpSignIn(tester, credentials);
    await submit(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(appels, 2);
    expect(avis, findsNothing, reason: 'l\'avis suit l\'état : il ne survit pas au succès');
  });

  testWidgets('l\'avis disparaît quand la reprise échoue aussi', (WidgetTester tester) async {
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String _, String __) => throw serveurLent,
    );
    await pumpSignIn(tester, credentials);
    await submit(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      avis,
      findsNothing,
      reason: 'un « on réessaie… » qui reste serait le prochain message faux',
    );
    expect(find.textContaining('serveur'), findsWidgets, reason: 'l\'échec, lui, reste affiché');
  });

  testWidgets('aucun avis de reprise sur un mot de passe incorrect', (WidgetTester tester) async {
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String _, String __) => throw const AuthGatewayException(
        'E-mail ou mot de passe incorrect.',
        cause: AuthFailureCause.invalidCredentials,
      ),
    );
    await pumpSignIn(tester, credentials);
    await submit(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(avis, findsNothing);
  });
}
