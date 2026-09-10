import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Reprise unique de la connexion e-mail quand le serveur n'a pas répondu à
/// temps — signature d'un backend qui démarre à froid, mesuré à 12 s puis
/// 593 ms à l'essai suivant.
void main() {
  AuthSession session(String email) => AuthSession(
        accessToken: 'jeton-$email',
        provider: AuthProvider.email,
        email: email,
      );

  ProviderContainer makeContainer(FakeCredentialsGateway credentials) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(FakeAuthGateway()),
        credentialsGatewayProvider.overrideWithValue(credentials),
        sessionStoreProvider.overrideWithValue(FakeSessionStore()),
        authConfiguredProvider.overrideWithValue(true),
        authRequiredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  const AuthGatewayException serveurLent = AuthGatewayException(
    'Le serveur met trop de temps à répondre. Réessayez dans un instant.',
    cause: AuthFailureCause.timeout,
  );

  test('un délai serveur déclenche UNE reprise, et la 2e tentative aboutit', () async {
    int appels = 0;
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String email, String _) {
        appels++;
        if (appels == 1) throw serveurLent;
        return session(email);
      },
    );
    final ProviderContainer container = makeContainer(credentials);
    container.read(authControllerProvider);
    await settle();

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'qa@certigo.co', password: 'Audit123!');

    expect(appels, 2, reason: 'exactement une reprise');
    expect(container.read(authControllerProvider), isA<Authenticated>());
  });

  test('l\'interface est prévenue de la reprise via AuthLoading.retrying', () async {
    int appels = 0;
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String email, String _) {
        appels++;
        if (appels == 1) throw serveurLent;
        return session(email);
      },
    );
    final ProviderContainer container = makeContainer(credentials);
    final List<AuthState> vus = <AuthState>[];
    container.listen<AuthState>(
      authControllerProvider,
      (AuthState? _, AuthState next) => vus.add(next),
      fireImmediately: true,
    );
    await settle();

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'qa@certigo.co', password: 'Audit123!');

    expect(
      vus.whereType<AuthLoading>().any((AuthLoading s) => s.retrying),
      isTrue,
      reason: 'sans ce signal, l\'écran afficherait 25 s d\'indicateur immobile',
    );
  });

  test('une seconde expiration n\'entraîne PAS de troisième tentative', () async {
    int appels = 0;
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String _, String __) {
        appels++;
        throw serveurLent;
      },
    );
    final ProviderContainer container = makeContainer(credentials);
    container.read(authControllerProvider);
    await settle();

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'qa@certigo.co', password: 'Audit123!');

    expect(appels, 2, reason: 'une seule reprise, pas de boucle');
    expect(container.read(authControllerProvider), isA<Unauthenticated>());
  });

  test('un mot de passe incorrect n\'est JAMAIS repris', () async {
    int appels = 0;
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onLogin: (String _, String __) {
        appels++;
        throw const AuthGatewayException(
          'E-mail ou mot de passe incorrect.',
          cause: AuthFailureCause.invalidCredentials,
        );
      },
    );
    final ProviderContainer container = makeContainer(credentials);
    container.read(authControllerProvider);
    await settle();

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'qa@certigo.co', password: 'mauvais-mdp');

    expect(appels, 1, reason: 'reprendre un refus d\'identifiants ferait attendre pour rien');
  });

  // Frontière mesurée : `auth/register` n'a aucune clé d'idempotence. Une
  // reprise après une inscription réussie mais expirée rendrait 409 et
  // afficherait « adresse déjà utilisée » à quelqu'un qui vient de créer son
  // compte — un message faux ET décourageant.
  test('l\'inscription n\'est JAMAIS reprise, même sur un délai serveur', () async {
    int appels = 0;
    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onRegister: (String _, String __, String? ___) {
        appels++;
        throw serveurLent;
      },
    );
    final ProviderContainer container = makeContainer(credentials);
    container.read(authControllerProvider);
    await settle();

    await container.read(authControllerProvider.notifier).registerWithEmail(
          email: 'qa2@certigo.co',
          password: 'Audit123!',
        );

    expect(appels, 1, reason: 'une inscription reprise peut créer un doublon');
    expect(container.read(authControllerProvider), isA<Unauthenticated>());
  });
}
