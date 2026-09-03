import 'dart:async';

import 'package:core/core.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/auth_telemetry.dart';
import 'package:certigo/features/auth/application/credentials_gateway.dart';
import 'package:certigo/features/auth/application/session_store.dart';
import 'package:certigo/app/capabilities/release_profile_provider.dart';

/// Passerelle OIDC factice : aucune dépendance plateforme, comportement
/// scriptable par test (succès, échec, jeton rafraîchi…).
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.onSignIn, this.onRefresh, this.onRefreshFuture, this.hangSignIn = false});

  AuthSession Function(AuthProvider provider)? onSignIn;
  AuthSession Function(String refreshToken)? onRefresh;
  Future<AuthSession> Function(String refreshToken)? onRefreshFuture;

  /// Quand `true`, [signIn] renvoie une future qui ne se résout jamais (sert à
  /// tester le filet de sécurité `.timeout()` via `fake_async`).
  bool hangSignIn;

  final List<AuthProvider> signInCalls = <AuthProvider>[];
  final List<String> refreshCalls = <String>[];
  final List<AuthProvider> reauthenticateCalls = <AuthProvider>[];
  int signOutCalls = 0;

  @override
  Future<AuthSession> signIn(AuthProvider provider) {
    signInCalls.add(provider);
    if (hangSignIn) return Completer<AuthSession>().future;
    final AuthSession Function(AuthProvider)? builder = onSignIn;
    if (builder == null) throw StateError('signIn non câblé');
    return Future<AuthSession>.value(builder(provider));
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls.add(refreshToken);
    final Future<AuthSession> Function(String)? asyncBuilder = onRefreshFuture;
    if (asyncBuilder != null) return asyncBuilder(refreshToken);
    final AuthSession Function(String)? builder = onRefresh;
    if (builder == null) throw StateError('refresh non câblé');
    return builder(refreshToken);
  }

  @override
  Future<AuthSession> reauthenticate(AuthProvider provider) async {
    reauthenticateCalls.add(provider);
    final AuthSession Function(AuthProvider)? builder = onSignIn;
    if (builder == null) throw StateError('reauthenticate non câblé');
    return builder(provider);
  }

  @override
  Future<void> signOut(AuthSession session) async {
    signOutCalls++;
  }
}

/// Passerelle e-mail/mot de passe factice (aucun réseau), scriptable par test.
class FakeCredentialsGateway implements CredentialsGateway {
  FakeCredentialsGateway({this.onLogin, this.onLoginFuture, this.onRegister, this.onRefresh});

  AuthSession Function(String email, String password)? onLogin;

  /// Variante asynchrone : permet de renvoyer une future en attente (test du
  /// spinner / anti-double-clic pendant qu'une connexion est en cours).
  Future<AuthSession> Function(String email, String password)? onLoginFuture;
  AuthSession Function(String email, String password, String? displayName)? onRegister;
  AuthSession Function(String refreshToken)? onRefresh;

  final List<String> loginCalls = <String>[];
  final List<String> registerCalls = <String>[];
  final List<String> refreshCalls = <String>[];
  final List<String> resendCalls = <String>[];

  @override
  Future<AuthSession> login({required String email, required String password}) {
    loginCalls.add(email);
    final Future<AuthSession> Function(String, String)? asyncBuilder = onLoginFuture;
    if (asyncBuilder != null) return asyncBuilder(email, password);
    final AuthSession Function(String, String)? builder = onLogin;
    if (builder == null) throw const AuthGatewayException('login non câblé');
    return Future<AuthSession>.value(builder(email, password));
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    registerCalls.add(email);
    final AuthSession Function(String, String, String?)? builder = onRegister;
    if (builder == null) throw const AuthGatewayException('register non câblé');
    return builder(email, password, displayName);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls.add(refreshToken);
    final AuthSession Function(String)? builder = onRefresh;
    if (builder == null) throw const AuthGatewayException('refresh non câblé');
    return builder(refreshToken);
  }

  @override
  Future<void> resendVerification(String email) async {
    resendCalls.add(email);
  }
}

/// Stockage de session en mémoire (remplace le coffre chiffré sous test).
class FakeSessionStore implements SessionStore {
  FakeSessionStore([this._session]) : failClear = false;

  FakeSessionStore.failingClear([this._session]) : failClear = true;

  AuthSession? _session;
  final bool failClear;
  int writeCalls = 0;
  int clearCalls = 0;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async {
    writeCalls++;
    _session = session;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    if (failClear) throw StateError('clear failed');
    _session = null;
  }
}

/// Télémétrie factice : enregistre chaque événement pour vérification.
class FakeAuthTelemetry implements AuthTelemetry {
  final List<String> starts = <String>[];
  final List<String> successes = <String>[];
  final List<({String method, AuthFailureCause cause})> failures =
      <({String method, AuthFailureCause cause})>[];

  @override
  void authStart(AuthMethod method) => starts.add(method.label);

  @override
  void authSuccess(AuthMethod method, {int? durationMs}) => successes.add(method.label);

  @override
  void authFailure(AuthMethod method, AuthFailureCause cause, {int? durationMs}) =>
      failures.add((method: method.label, cause: cause));
}

void main() {
  /// Draine entièrement la file de micro-tâches (le `_restore` différé du
  /// contrôleur et ses `await` enchaînés) sans déclencher de timer.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ProviderContainer makeContainer({
    required FakeAuthGateway gateway,
    required FakeSessionStore store,
    FakeCredentialsGateway? credentials,
    FakeAuthTelemetry? telemetry,
    AuthLocalAccountCleanup? localAccountCleanup,
    bool configured = true,
    bool required = true,
    ReleaseProfile releaseProfile = ReleaseProfile.full,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        releaseProfileProvider.overrideWithValue(releaseProfile),
        authGatewayProvider.overrideWithValue(gateway),
        credentialsGatewayProvider.overrideWithValue(credentials ?? FakeCredentialsGateway()),
        sessionStoreProvider.overrideWithValue(store),
        authConfiguredProvider.overrideWithValue(configured),
        authRequiredProvider.overrideWithValue(required),
        if (localAccountCleanup != null)
          authLocalAccountCleanupProvider.overrideWithValue(localAccountCleanup),
        if (telemetry != null) authTelemetryProvider.overrideWithValue(telemetry),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  AuthSession session({
    String accessToken = 'access',
    String? refreshToken = 'refresh',
    DateTime? expiry,
  }) => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiry: expiry,
    provider: AuthProvider.microsoft,
  );

  group('restauration au démarrage (auto-connexion)', () {
    test('sans session stockée → Unauthenticated', () async {
      final FakeSessionStore store = FakeSessionStore();
      final ProviderContainer container = makeContainer(gateway: FakeAuthGateway(), store: store);

      container.read(authControllerProvider);
      await settle();

      expect(container.read(authControllerProvider), isA<Unauthenticated>());
    });

    test('avec session valide → Authenticated, sans toucher au réseau', () async {
      final FakeSessionStore store = FakeSessionStore(session());
      final FakeAuthGateway gateway = FakeAuthGateway();
      final ProviderContainer container = makeContainer(gateway: gateway, store: store);

      container.read(authControllerProvider);
      await settle();

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.accessToken, 'access');
      expect(gateway.refreshCalls, isEmpty);
    });

    test('avec session expirée → rafraîchissement silencieux → Authenticated', () async {
      final FakeSessionStore store = FakeSessionStore(
        session(expiry: DateTime.now().subtract(const Duration(minutes: 5))),
      );
      final FakeAuthGateway gateway = FakeAuthGateway(
        onRefresh: (_) => session(accessToken: 'frais'),
      );
      final ProviderContainer container = makeContainer(gateway: gateway, store: store);

      container.read(authControllerProvider);
      await settle();

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.accessToken, 'frais');
      expect(gateway.refreshCalls, hasLength(1));
      expect(store.writeCalls, 1);
    });

    test('session expirée + rafraîchissement échoué → Unauthenticated', () async {
      final FakeSessionStore store = FakeSessionStore(
        session(expiry: DateTime.now().subtract(const Duration(minutes: 5))),
      );
      // onRefresh non câblé → lève → échec de rafraîchissement.
      final ProviderContainer container = makeContainer(gateway: FakeAuthGateway(), store: store);

      container.read(authControllerProvider);
      await settle();

      expect(container.read(authControllerProvider), isA<Unauthenticated>());
    });
  });

  group('connexion explicite', () {
    test('succès → Authenticated + session persistée', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (AuthProvider p) => session(accessToken: 'jeton-${p.id}'),
      );
      final ProviderContainer container = makeContainer(gateway: gateway, store: store);
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.google);

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.accessToken, 'jeton-google');
      expect(gateway.signInCalls, <AuthProvider>[AuthProvider.google]);
      expect(store.writeCalls, 1);
      expect((await store.read())?.accessToken, 'jeton-google');
    });

    test('échec de la passerelle → message d\'erreur, Unauthenticated', () async {
      final FakeSessionStore store = FakeSessionStore();
      // onSignIn non câblé → la passerelle lève.
      final ProviderContainer container = makeContainer(gateway: FakeAuthGateway(), store: store);
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.apple);

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      // L'erreur inattendue est désormais **révélée** (build de diagnostic) :
      // message convivial + détail technique (type + toString) concaténé,
      // jamais avalé derrière un message générique.
      final String? message = (state as Unauthenticated).message;
      expect(message, startsWith('Connexion Apple échouée.'));
      expect(message, contains('[technique]'));
      expect(message, contains('StateError'));
      expect(store.writeCalls, 0);
    });

    test('erreur métier passerelle → message explicite propagé', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (_) => throw const AuthGatewayException('Configuration de redirection invalide.'),
      );
      final ProviderContainer container = makeContainer(gateway: gateway, store: store);
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.microsoft);

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).message, 'Configuration de redirection invalide.');
      expect(store.writeCalls, 0);
    });

    test('Entra non configuré → message de configuration, aucun appel passerelle', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeAuthGateway gateway = FakeAuthGateway(onSignIn: (_) => session());
      // required=true (UI forcée) mais configured=false.
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: store,
        configured: false,
      );
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.microsoft);

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).message, contains('Configuration Entra requise'));
      expect(gateway.signInCalls, isEmpty);
    });
  });

  test('déconnexion → passerelle notifiée, stockage effacé, Unauthenticated', () async {
    final FakeSessionStore store = FakeSessionStore(session());
    final FakeAuthGateway gateway = FakeAuthGateway();
    var cleanupCalls = 0;
    final ProviderContainer container = makeContainer(
      gateway: gateway,
      store: store,
      localAccountCleanup: () async {
        cleanupCalls++;
        expect(await store.read(), isNotNull);
      },
    );
    container.read(authControllerProvider);
    await settle();
    expect(container.read(authControllerProvider), isA<Authenticated>());

    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(authControllerProvider), isA<Unauthenticated>());
    expect(
      (container.read(authControllerProvider) as Unauthenticated).clearLocalAccountData,
      isTrue,
    );
    expect(gateway.signOutCalls, 1);
    expect(cleanupCalls, 1);
    expect(store.clearCalls, 1);
    expect(await store.read(), isNull);
  });

  test('déconnexion efface la session même si le nettoyage local échoue', () async {
    final FakeSessionStore store = FakeSessionStore(session());
    final ProviderContainer container = makeContainer(
      gateway: FakeAuthGateway(),
      store: store,
      localAccountCleanup: () async => throw StateError('cleanup failed'),
    );
    container.read(authControllerProvider);
    await settle();

    await container.read(authControllerProvider.notifier).signOut();

    final AuthState state = container.read(authControllerProvider);
    expect(state, isA<Unauthenticated>());
    expect((state as Unauthenticated).clearLocalAccountData, isTrue);
    expect(state.message, contains('Déconnexion terminée'));
    expect(store.clearCalls, 1);
    expect(await store.read(), isNull);
  });

  test('déconnexion reste authentifiée si le tombstone de session échoue', () async {
    final FakeSessionStore store = FakeSessionStore.failingClear(session());
    final ProviderContainer container = makeContainer(gateway: FakeAuthGateway(), store: store);
    container.read(authControllerProvider);
    await settle();

    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(authControllerProvider), isA<Authenticated>());
    expect(store.clearCalls, 1);
    expect(await store.read(), isNotNull);
  });

  test('un refresh obsolète ne peut pas ressusciter une session déconnectée', () async {
    final Completer<AuthSession> refresh = Completer<AuthSession>();
    final FakeSessionStore store = FakeSessionStore(
      session(expiry: DateTime.now().subtract(const Duration(minutes: 1))),
    );
    final ProviderContainer container = makeContainer(
      gateway: FakeAuthGateway(onRefreshFuture: (_) => refresh.future),
      store: store,
    );
    container.read(authControllerProvider);
    await settle();

    await container.read(authControllerProvider.notifier).signOut();
    refresh.complete(session(accessToken: 'stale-refresh'));
    await settle();
    await settle();

    final AuthState state = container.read(authControllerProvider);
    expect(state, isA<Unauthenticated>());
    expect((state as Unauthenticated).clearLocalAccountData, isTrue);
    expect(await store.read(), isNull);
  });

  group('jeton d\'accès courant', () {
    test('rafraîchit de façon proactive quand le jeton va bientôt expirer', () async {
      final FakeSessionStore store = FakeSessionStore(
        session(accessToken: 'ancien', expiry: DateTime.now().add(const Duration(seconds: 30))),
      );
      final FakeAuthGateway gateway = FakeAuthGateway(
        onRefresh: (_) =>
            session(accessToken: 'nouveau', expiry: DateTime.now().add(const Duration(hours: 1))),
      );
      final ProviderContainer container = makeContainer(gateway: gateway, store: store);
      container.read(authControllerProvider);
      await settle();

      final String? token = await container
          .read(authControllerProvider.notifier)
          .currentAccessToken();

      expect(token, 'nouveau');
      expect(gateway.refreshCalls, hasLength(1));
      expect(
        (container.read(authControllerProvider) as Authenticated).session.accessToken,
        'nouveau',
      );
    });
  });

  group('réponse 401', () {
    test('rafraîchissement réussi → reste Authenticated', () async {
      final FakeSessionStore store = FakeSessionStore(session());
      final FakeAuthGateway gateway = FakeAuthGateway(
        onRefresh: (_) => session(accessToken: 'rafraichi'),
      );
      final ProviderContainer container = makeContainer(gateway: gateway, store: store);
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).handleUnauthorized();

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.accessToken, 'rafraichi');
    });

    test('rafraîchissement impossible → session effacée, Unauthenticated', () async {
      final FakeSessionStore store = FakeSessionStore(session());
      // onRefresh non câblé → échec.
      final ProviderContainer container = makeContainer(gateway: FakeAuthGateway(), store: store);
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).handleUnauthorized();

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).message, 'Votre session a expiré. Reconnectez-vous.');
      expect(state.clearLocalAccountData, isFalse);
      expect(store.clearCalls, 1);
    });
  });

  group('passage direct en dev (Entra non requis)', () {
    test('restauration → Authenticated sans lire le stockage ni le réseau', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeAuthGateway gateway = FakeAuthGateway();
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: store,
        configured: false,
        required: false,
      );

      container.read(authControllerProvider);
      await settle();

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.displayName, 'Développeur');
      expect(gateway.signInCalls, isEmpty);
    });

    test('jeton courant = jeton dev', () async {
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: FakeSessionStore(),
        configured: false,
        required: false,
      );
      container.read(authControllerProvider);
      await settle();

      final String? token = await container
          .read(authControllerProvider.notifier)
          .currentAccessToken();
      expect(token, AppEnv.devAuthToken);
    });
  });

  group('connexion e-mail / mot de passe', () {
    test('connexion réussie → Authenticated + session persistée', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onLogin: (String email, String password) => AuthSession(
          accessToken: 'jeton-$email',
          refreshToken: 'refresh-email',
          provider: AuthProvider.email,
          email: email,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
        credentials: credentials,
      );
      container.read(authControllerProvider);
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'a@b.com', password: 'password123');

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.accessToken, 'jeton-a@b.com');
      expect(credentials.loginCalls, <String>['a@b.com']);
      expect(store.writeCalls, 1);
    });

    test('création de compte réussie → Authenticated', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onRegister: (String email, String password, String? name) => AuthSession(
          accessToken: 'nouveau-jeton',
          refreshToken: 'refresh-email',
          provider: AuthProvider.email,
          displayName: name,
          email: email,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
        credentials: credentials,
      );
      container.read(authControllerProvider);
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .registerWithEmail(email: 'new@b.com', password: 'password123', displayName: 'Alice');

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.displayName, 'Alice');
      expect(credentials.registerCalls, <String>['new@b.com']);
      expect(store.writeCalls, 1);
    });

    test('Alpha privée refuse l’inscription sans réseau, stockage ni télémétrie', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onRegister: (_, __, ___) => const AuthSession(accessToken: 'unexpected'),
      );
      final FakeAuthTelemetry telemetry = FakeAuthTelemetry();
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
        credentials: credentials,
        telemetry: telemetry,
        releaseProfile: ReleaseProfile.privateAlpha,
      );
      container.read(authControllerProvider);
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .registerWithEmail(email: 'test@example.invalid', password: 'password123');

      expect(credentials.registerCalls, isEmpty);
      expect(store.writeCalls, 0);
      expect(telemetry.starts, isEmpty);
      expect(container.read(authControllerProvider), isA<Unauthenticated>());
    });

    test('inscription non vérifiée → session.emailVerified = false', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onRegister: (String email, String password, String? name) => AuthSession(
          accessToken: 'jeton',
          refreshToken: 'refresh-email',
          provider: AuthProvider.email,
          email: email,
          emailVerified: false,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
        credentials: credentials,
      );
      container.read(authControllerProvider);
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .registerWithEmail(email: 'pending@b.com', password: 'password123');

      final AuthState state = container.read(authControllerProvider);
      expect((state as Authenticated).session.emailVerified, isFalse);
    });

    test('resendVerificationEmail relaie l\'e-mail du compte connecté', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onLogin: (String email, String password) => AuthSession(
          accessToken: 'jeton',
          refreshToken: 'refresh-email',
          provider: AuthProvider.email,
          email: email,
          emailVerified: false,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
        credentials: credentials,
      );
      container.read(authControllerProvider);
      await settle();
      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'pending@b.com', password: 'password123');

      final bool ok = await container
          .read(authControllerProvider.notifier)
          .resendVerificationEmail();

      expect(ok, isTrue);
      expect(credentials.resendCalls, <String>['pending@b.com']);
    });

    test('un refresh e-mail conserve l\'e-mail → renvoi de vérification possible', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onLogin: (String email, String password) => AuthSession(
          accessToken: 'jeton',
          refreshToken: 'refresh-email',
          provider: AuthProvider.email,
          email: email,
          emailVerified: false,
        ),
        // La réponse /auth/refresh omet volontairement l'e-mail.
        onRefresh: (String token) => const AuthSession(
          accessToken: 'jeton-2',
          refreshToken: 'refresh-email-2',
          provider: AuthProvider.email,
          emailVerified: false,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
        credentials: credentials,
      );
      container.read(authControllerProvider);
      await settle();
      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'pending@b.com', password: 'password123');

      // Simule le refresh silencieux (ex. bouton « J'ai confirmé »).
      await container.read(authControllerProvider.notifier).reloadVerificationStatus();

      final AuthState state = container.read(authControllerProvider);
      expect((state as Authenticated).session.accessToken, 'jeton-2');
      expect(state.session.email, 'pending@b.com'); // reporté malgré l'absence côté API

      final bool ok = await container
          .read(authControllerProvider.notifier)
          .resendVerificationEmail();
      expect(ok, isTrue);
      expect(credentials.resendCalls, <String>['pending@b.com']);
    });

    test('échec de connexion → message d\'erreur propagé', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onLogin: (_, __) => throw const AuthGatewayException('E-mail ou mot de passe incorrect.'),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
        credentials: credentials,
      );
      container.read(authControllerProvider);
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'a@b.com', password: 'wrongwrong');

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).message, 'E-mail ou mot de passe incorrect.');
      expect(store.writeCalls, 0);
    });

    test('session e-mail expirée → rafraîchie via la passerelle credentials', () async {
      final FakeSessionStore store = FakeSessionStore(
        AuthSession(
          accessToken: 'ancien',
          refreshToken: 'refresh-email',
          accessTokenExpiry: DateTime.now().subtract(const Duration(minutes: 5)),
          provider: AuthProvider.email,
        ),
      );
      final FakeAuthGateway gateway = FakeAuthGateway();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onRefresh: (String token) => AuthSession(
          accessToken: 'frais-email',
          refreshToken: token,
          provider: AuthProvider.email,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: store,
        credentials: credentials,
      );

      container.read(authControllerProvider);
      await settle();

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.accessToken, 'frais-email');
      // Le rafraîchissement passe par credentials, pas par la passerelle OIDC.
      expect(credentials.refreshCalls, hasLength(1));
      expect(gateway.refreshCalls, isEmpty);
    });
  });

  group('timeout, annulation & causes normalisées (P2)', () {
    test('connexion sociale sans timeout → succès + télémétrie start/success', () async {
      final FakeAuthTelemetry telemetry = FakeAuthTelemetry();
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (AuthProvider p) => session(accessToken: 'jeton-${p.id}'),
      );
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: FakeSessionStore(),
        telemetry: telemetry,
      );
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.google);

      expect(container.read(authControllerProvider), isA<Authenticated>());
      expect(telemetry.starts, contains('google'));
      expect(telemetry.successes, contains('google'));
    });

    test('annulation sociale → message « Connexion annulée. » + cause cancelled', () async {
      final FakeAuthTelemetry telemetry = FakeAuthTelemetry();
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (_) => throw const AuthGatewayException(
          'Connexion annulée.',
          cause: AuthFailureCause.cancelled,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: FakeSessionStore(),
        telemetry: telemetry,
      );
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.apple);

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).message, 'Connexion annulée.');
      expect(telemetry.failures.single.cause, AuthFailureCause.cancelled);
    });

    test('connexion sociale qui ne répond jamais → timeout + cause timeout', () {
      fakeAsync((FakeAsync async) {
        final FakeAuthTelemetry telemetry = FakeAuthTelemetry();
        final FakeAuthGateway gateway = FakeAuthGateway(hangSignIn: true);
        final ProviderContainer container = makeContainer(
          gateway: gateway,
          store: FakeSessionStore(),
          telemetry: telemetry,
        );
        container.read(authControllerProvider);
        async.flushMicrotasks();

        container.read(authControllerProvider.notifier).signIn(AuthProvider.microsoft);
        // Avance au-delà du filet de sécurité social (45 s) : plus jamais de
        // spinner infini, l'état repasse à Unauthenticated avec un message clair.
        async.elapse(const Duration(seconds: 46));
        async.flushMicrotasks();

        final AuthState state = container.read(authControllerProvider);
        expect(state, isA<Unauthenticated>());
        final String? message = (state as Unauthenticated).message;
        expect(message, startsWith('Connexion Microsoft expirée : aucune réponse après 45s.'));
        expect(message, contains('TimeoutException'));
        expect(telemetry.failures.last.cause, AuthFailureCause.timeout);
      });
    });

    test('détail technique de la passerelle propagé dans le message (diagnostic)', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (_) => throw const AuthGatewayException(
          'Fournisseur microsoft indisponible dans Entra External ID.',
          cause: AuthFailureCause.providerError,
          diagnostic: 'PlatformException code=access_denied msg=IdP refusé',
        ),
      );
      final ProviderContainer container = makeContainer(gateway: gateway, store: store);
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.microsoft);

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      final String? message = (state as Unauthenticated).message;
      // Le message convivial ET le détail technique brut sont présents à l'écran.
      expect(message, contains('Fournisseur microsoft indisponible'));
      expect(message, contains('[technique] PlatformException code=access_denied'));
      expect(store.writeCalls, 0);
    });

    test('erreur réseau e-mail → message réseau + cause network', () async {
      final FakeAuthTelemetry telemetry = FakeAuthTelemetry();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onLogin: (_, __) => throw const AuthGatewayException(
          'Pas de connexion. Vérifiez votre réseau puis réessayez.',
          cause: AuthFailureCause.network,
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: FakeSessionStore(),
        credentials: credentials,
        telemetry: telemetry,
      );
      container.read(authControllerProvider);
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'a@b.com', password: 'password123');

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect(
        (state as Unauthenticated).message,
        'Pas de connexion. Vérifiez votre réseau puis réessayez.',
      );
      expect(telemetry.failures.single, (method: 'email', cause: AuthFailureCause.network));
    });

    test('création de compte → télémétrie register start/success', () async {
      final FakeAuthTelemetry telemetry = FakeAuthTelemetry();
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onRegister: (String email, String password, String? name) =>
            AuthSession(accessToken: 'jeton', provider: AuthProvider.email, email: email),
      );
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: FakeSessionStore(),
        credentials: credentials,
        telemetry: telemetry,
      );
      container.read(authControllerProvider);
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .registerWithEmail(email: 'new@b.com', password: 'password123');

      expect(container.read(authControllerProvider), isA<Authenticated>());
      expect(telemetry.starts, contains('register'));
      expect(telemetry.successes, contains('register'));
    });

    test('Entra non configuré → cause configError en télémétrie', () async {
      final FakeAuthTelemetry telemetry = FakeAuthTelemetry();
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(onSignIn: (_) => session()),
        store: FakeSessionStore(),
        telemetry: telemetry,
        configured: false,
      );
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.microsoft);

      expect(telemetry.failures.single.cause, AuthFailureCause.configError);
    });
  });
}
