import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/credentials_gateway.dart';
import 'package:certigo/features/auth/application/session_store.dart';

/// Passerelle OIDC factice : aucune dépendance plateforme, comportement
/// scriptable par test (succès, échec, jeton rafraîchi…).
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.onSignIn, this.onRefresh});

  AuthSession Function(AuthProvider provider)? onSignIn;
  AuthSession Function(String refreshToken)? onRefresh;

  final List<AuthProvider> signInCalls = <AuthProvider>[];
  final List<String> refreshCalls = <String>[];
  int signOutCalls = 0;

  @override
  Future<AuthSession> signIn(AuthProvider provider) async {
    signInCalls.add(provider);
    final AuthSession Function(AuthProvider)? builder = onSignIn;
    if (builder == null) throw StateError('signIn non câblé');
    return builder(provider);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls.add(refreshToken);
    final AuthSession Function(String)? builder = onRefresh;
    if (builder == null) throw StateError('refresh non câblé');
    return builder(refreshToken);
  }

  @override
  Future<void> signOut(AuthSession session) async {
    signOutCalls++;
  }
}

/// Passerelle e-mail/mot de passe factice (aucun réseau), scriptable par test.
class FakeCredentialsGateway implements CredentialsGateway {
  FakeCredentialsGateway({this.onLogin, this.onRegister, this.onRefresh});

  AuthSession Function(String email, String password)? onLogin;
  AuthSession Function(String email, String password, String? displayName)? onRegister;
  AuthSession Function(String refreshToken)? onRefresh;

  final List<String> loginCalls = <String>[];
  final List<String> registerCalls = <String>[];
  final List<String> refreshCalls = <String>[];

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    loginCalls.add(email);
    final AuthSession Function(String, String)? builder = onLogin;
    if (builder == null) throw const AuthGatewayException('login non câblé');
    return builder(email, password);
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
}

/// Stockage de session en mémoire (remplace le coffre chiffré sous test).
class FakeSessionStore implements SessionStore {
  FakeSessionStore([this._session]);

  AuthSession? _session;
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
    _session = null;
  }
}

void main() {
  /// Draine entièrement la file de micro-tâches (le `_restore` différé du
  /// contrôleur et ses `await` enchaînés) sans déclencher de timer.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ProviderContainer makeContainer({
    required FakeAuthGateway gateway,
    required FakeSessionStore store,
    FakeCredentialsGateway? credentials,
    bool configured = true,
    bool required = true,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(gateway),
        credentialsGatewayProvider.overrideWithValue(
          credentials ?? FakeCredentialsGateway(),
        ),
        sessionStoreProvider.overrideWithValue(store),
        authConfiguredProvider.overrideWithValue(configured),
        authRequiredProvider.overrideWithValue(required),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  AuthSession session({
    String accessToken = 'access',
    String? refreshToken = 'refresh',
    DateTime? expiry,
  }) =>
      AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiry: expiry,
        provider: AuthProvider.microsoft,
      );

  group('restauration au démarrage (auto-connexion)', () {
    test('sans session stockée → Unauthenticated', () async {
      final FakeSessionStore store = FakeSessionStore();
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: store,
      );

      container.read(authControllerProvider);
      await settle();

      expect(container.read(authControllerProvider), isA<Unauthenticated>());
    });

    test(
      'avec session valide → Authenticated, sans toucher au réseau',
      () async {
        final FakeSessionStore store = FakeSessionStore(session());
        final FakeAuthGateway gateway = FakeAuthGateway();
        final ProviderContainer container = makeContainer(
          gateway: gateway,
          store: store,
        );

        container.read(authControllerProvider);
        await settle();

        final AuthState state = container.read(authControllerProvider);
        expect(state, isA<Authenticated>());
        expect((state as Authenticated).session.accessToken, 'access');
        expect(gateway.refreshCalls, isEmpty);
      },
    );

    test(
      'avec session expirée → rafraîchissement silencieux → Authenticated',
      () async {
        final FakeSessionStore store = FakeSessionStore(
          session(expiry: DateTime.now().subtract(const Duration(minutes: 5))),
        );
        final FakeAuthGateway gateway = FakeAuthGateway(
          onRefresh: (_) => session(accessToken: 'frais'),
        );
        final ProviderContainer container = makeContainer(
          gateway: gateway,
          store: store,
        );

        container.read(authControllerProvider);
        await settle();

        final AuthState state = container.read(authControllerProvider);
        expect(state, isA<Authenticated>());
        expect((state as Authenticated).session.accessToken, 'frais');
        expect(gateway.refreshCalls, hasLength(1));
        expect(store.writeCalls, 1);
      },
    );

    test(
      'session expirée + rafraîchissement échoué → Unauthenticated',
      () async {
        final FakeSessionStore store = FakeSessionStore(
          session(expiry: DateTime.now().subtract(const Duration(minutes: 5))),
        );
        // onRefresh non câblé → lève → échec de rafraîchissement.
        final ProviderContainer container = makeContainer(
          gateway: FakeAuthGateway(),
          store: store,
        );

        container.read(authControllerProvider);
        await settle();

        expect(container.read(authControllerProvider), isA<Unauthenticated>());
      },
    );
  });

  group('connexion explicite', () {
    test('succès → Authenticated + session persistée', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (AuthProvider p) => session(accessToken: 'jeton-${p.id}'),
      );
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: store,
      );
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

    test(
      'échec de la passerelle → message d\'erreur, Unauthenticated',
      () async {
        final FakeSessionStore store = FakeSessionStore();
        // onSignIn non câblé → la passerelle lève.
        final ProviderContainer container = makeContainer(
          gateway: FakeAuthGateway(),
          store: store,
        );
        container.read(authControllerProvider);
        await settle();

        await container.read(authControllerProvider.notifier).signIn(AuthProvider.apple);

        final AuthState state = container.read(authControllerProvider);
        expect(state, isA<Unauthenticated>());
        expect(
          (state as Unauthenticated).message,
          'La connexion a échoué. Réessayez.',
        );
        expect(store.writeCalls, 0);
      },
    );

    test('erreur métier passerelle → message explicite propagé', () async {
      final FakeSessionStore store = FakeSessionStore();
      final FakeAuthGateway gateway = FakeAuthGateway(
        onSignIn: (_) => throw const AuthGatewayException(
          'Configuration de redirection invalide.',
        ),
      );
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: store,
      );
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).signIn(AuthProvider.microsoft);

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect(
        (state as Unauthenticated).message,
        'Configuration de redirection invalide.',
      );
      expect(store.writeCalls, 0);
    });

    test(
      'Entra non configuré → message de configuration, aucun appel passerelle',
      () async {
        final FakeSessionStore store = FakeSessionStore();
        final FakeAuthGateway gateway = FakeAuthGateway(
          onSignIn: (_) => session(),
        );
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
        expect(
          (state as Unauthenticated).message,
          contains('Configuration Entra requise'),
        );
        expect(gateway.signInCalls, isEmpty);
      },
    );
  });

  test(
    'déconnexion → passerelle notifiée, stockage effacé, Unauthenticated',
    () async {
      final FakeSessionStore store = FakeSessionStore(session());
      final FakeAuthGateway gateway = FakeAuthGateway();
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: store,
      );
      container.read(authControllerProvider);
      await settle();
      expect(container.read(authControllerProvider), isA<Authenticated>());

      await container.read(authControllerProvider.notifier).signOut();

      expect(container.read(authControllerProvider), isA<Unauthenticated>());
      expect(gateway.signOutCalls, 1);
      expect(store.clearCalls, 1);
      expect(await store.read(), isNull);
    },
  );

  group('jeton d\'accès courant', () {
    test(
      'rafraîchit de façon proactive quand le jeton va bientôt expirer',
      () async {
        final FakeSessionStore store = FakeSessionStore(
          session(
            accessToken: 'ancien',
            expiry: DateTime.now().add(const Duration(seconds: 30)),
          ),
        );
        final FakeAuthGateway gateway = FakeAuthGateway(
          onRefresh: (_) => session(
            accessToken: 'nouveau',
            expiry: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
        final ProviderContainer container = makeContainer(
          gateway: gateway,
          store: store,
        );
        container.read(authControllerProvider);
        await settle();

        final String? token =
            await container.read(authControllerProvider.notifier).currentAccessToken();

        expect(token, 'nouveau');
        expect(gateway.refreshCalls, hasLength(1));
        expect(
          (container.read(authControllerProvider) as Authenticated).session.accessToken,
          'nouveau',
        );
      },
    );
  });

  group('réponse 401', () {
    test('rafraîchissement réussi → reste Authenticated', () async {
      final FakeSessionStore store = FakeSessionStore(session());
      final FakeAuthGateway gateway = FakeAuthGateway(
        onRefresh: (_) => session(accessToken: 'rafraichi'),
      );
      final ProviderContainer container = makeContainer(
        gateway: gateway,
        store: store,
      );
      container.read(authControllerProvider);
      await settle();

      await container.read(authControllerProvider.notifier).handleUnauthorized();

      final AuthState state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).session.accessToken, 'rafraichi');
    });

    test(
      'rafraîchissement impossible → session effacée, Unauthenticated',
      () async {
        final FakeSessionStore store = FakeSessionStore(session());
        // onRefresh non câblé → échec.
        final ProviderContainer container = makeContainer(
          gateway: FakeAuthGateway(),
          store: store,
        );
        container.read(authControllerProvider);
        await settle();

        await container.read(authControllerProvider.notifier).handleUnauthorized();

        final AuthState state = container.read(authControllerProvider);
        expect(state, isA<Unauthenticated>());
        expect(
          (state as Unauthenticated).message,
          'Votre session a expiré. Reconnectez-vous.',
        );
        expect(store.clearCalls, 1);
      },
    );
  });

  group('passage direct en dev (Entra non requis)', () {
    test(
      'restauration → Authenticated sans lire le stockage ni le réseau',
      () async {
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
      },
    );

    test('jeton courant = jeton dev', () async {
      final ProviderContainer container = makeContainer(
        gateway: FakeAuthGateway(),
        store: FakeSessionStore(),
        configured: false,
        required: false,
      );
      container.read(authControllerProvider);
      await settle();

      final String? token =
          await container.read(authControllerProvider.notifier).currentAccessToken();
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
}
