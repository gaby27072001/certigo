import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_diagnostics.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/auth_telemetry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_controller_test.dart'
    show FakeAuthGateway, FakeAuthTelemetry, FakeCredentialsGateway, FakeSessionStore;

/// Ce que le contrôleur transmet au puits de télémétrie quand une connexion
/// sociale ou une vérification avant suppression échoue : le flux, la dernière
/// étape franchie et la signature technique. C'est ce qui rend un échec sur
/// l'iPhone d'un testeur lisible depuis Sentry (#307).
void main() {
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  const AuthFailureSignature appleRefusal = AuthFailureSignature(
    pluginCode: 'authorize_failed',
    nativeType: 'org.openid.appauth.oauth_authorization',
    nativeCode: '-2',
    oauthError: 'invalid_request',
    errorType: 'FlutterAppAuthPlatformException',
  );

  late FakeAuthGateway gateway;
  late FakeAuthTelemetry telemetry;
  late ProviderContainer container;

  setUp(() async {
    gateway = FakeAuthGateway();
    telemetry = FakeAuthTelemetry();
    container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(gateway),
        credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
        sessionStoreProvider.overrideWithValue(FakeSessionStore()),
        authConfiguredProvider.overrideWithValue(true),
        authRequiredProvider.overrideWithValue(true),
        authTelemetryProvider.overrideWithValue(telemetry),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await settle();
  });

  AuthController controller() => container.read(authControllerProvider.notifier);

  /// Rejoue les marques que pose la vraie passerelle, dans le même puits.
  void mark(AuthDiagnosticStep step) => container.read(authDiagnosticsProvider.notifier).mark(step);

  /// Connecte un compte Apple, comme le ferait un premier passage réussi.
  Future<void> signInWithApple() async {
    gateway.onSignIn = (AuthProvider provider) {
      mark(AuthDiagnosticStep.authorizeOpened);
      mark(AuthDiagnosticStep.callbackReturned);
      mark(AuthDiagnosticStep.tokenExchangeStarted);
      mark(AuthDiagnosticStep.tokenReceived);
      return AuthSession(
        accessToken: 'access',
        idToken: 'id-token',
        userId: 'user-1',
        provider: provider,
      );
    };
    await controller().signIn(AuthProvider.apple);
    expect(container.read(authControllerProvider), isA<Authenticated>());
  }

  group('connexion sociale', () {
    test('un refus transmet le flux, la dernière étape franchie et la signature', () async {
      gateway.onSignIn = (_) {
        mark(AuthDiagnosticStep.authorizeOpened);
        mark(AuthDiagnosticStep.failed);
        throw const AuthGatewayException(
          'refus',
          cause: AuthFailureCause.providerError,
          signature: appleRefusal,
        );
      };

      await controller().signIn(AuthProvider.apple);

      expect(telemetry.failures.single, (method: 'apple', cause: AuthFailureCause.providerError));
      final AuthFailureDetail detail = telemetry.failureDetails.single!;
      expect(detail.flow, AuthFlow.signIn);
      expect(detail.lastStep, AuthDiagnosticStep.authorizeOpened);
      expect(detail.signature, same(appleRefusal));
    });

    test('un jeton vide reçoit sa propre signature', () async {
      gateway.onSignIn = (_) {
        mark(AuthDiagnosticStep.authorizeOpened);
        mark(AuthDiagnosticStep.tokenReceived);
        return const AuthSession(accessToken: '', provider: AuthProvider.google);
      };

      await controller().signIn(AuthProvider.google);

      final AuthFailureDetail detail = telemetry.failureDetails.single!;
      expect(detail.flow, AuthFlow.signIn);
      expect(detail.lastStep, AuthDiagnosticStep.tokenReceived);
      expect(detail.signature?.errorType, 'EmptyAccessToken');
    });

    test('une erreur inattendue transmet son seul type', () async {
      gateway.onSignIn = (_) => throw StateError('user@example.com');

      await controller().signIn(AuthProvider.microsoft);

      expect(telemetry.failures.single.cause, AuthFailureCause.unknown);
      expect(telemetry.failureDetails.single?.signature?.errorType, 'StateError');
    });
  });

  group('vérification avant suppression', () {
    test('un échec est rapporté comme ré-authentification, avec une trace vierge', () async {
      await signInWithApple();
      gateway.onSignIn = (_) {
        mark(AuthDiagnosticStep.authorizeOpened);
        throw const AuthGatewayException(
          'Connexion annulée.',
          cause: AuthFailureCause.cancelled,
          signature: AuthFailureSignature(
            nativeType: 'org.openid.appauth.general',
            nativeCode: '-3',
          ),
        );
      };

      await controller().reauthenticateForAccountDeletion(expectedUserId: 'user-1');

      expect(telemetry.failures.single, (method: 'apple', cause: AuthFailureCause.cancelled));
      final AuthFailureDetail detail = telemetry.failureDetails.single!;
      expect(detail.flow, AuthFlow.reauthentication);
      expect(detail.lastStep, AuthDiagnosticStep.authorizeOpened);
      expect(detail.signature?.nativeCode, '-3');
      // La trace de la connexion précédente ne se mélange pas à celle de la
      // vérification : sinon un échec avant toute étape hériterait de
      // « session écrite ».
      expect(
        container.read(authDiagnosticsProvider).map((AuthDiagnosticEntry e) => e.step),
        <AuthDiagnosticStep>[AuthDiagnosticStep.authorizeOpened],
      );
    });

    test('une fenêtre fermée : cause, compte intact et action, sans présumer un geste', () async {
      await signInWithApple();
      gateway.onSignIn = (_) => throw const AuthGatewayException(
            'Connexion annulée.',
            cause: AuthFailureCause.cancelled,
          );

      final SensitiveReauthenticationResult result =
          await controller().reauthenticateForAccountDeletion(expectedUserId: 'user-1');

      expect(result.succeeded, isFalse);
      expect(
        result.message,
        'La vérification Apple n\'a pas abouti : la fenêtre a été fermée ou n\'a pas pu '
        's\'ouvrir. Votre compte n\'a pas été supprimé. Réessayez pour confirmer la suppression.',
      );
    });

    test('un refus du fournisseur ne montre ni détail technique ni consigne Entra', () async {
      await signInWithApple();
      gateway.onSignIn = (_) => throw const AuthGatewayException(
            'La connexion via apple a échoué. Vérifiez la configuration Entra puis réessayez.',
            cause: AuthFailureCause.providerError,
            diagnostic: 'PlatformException code=authorize_failed msg=invalid_request',
          );

      final SensitiveReauthenticationResult result =
          await controller().reauthenticateForAccountDeletion(expectedUserId: 'user-1');

      expect(
        result.message,
        'La vérification Apple a échoué. Votre compte n\'a pas été supprimé. '
        'Réessayez dans un instant.',
      );
      expect(result.message, isNot(contains('Entra')));
      expect(result.message, isNot(contains('PlatformException')));
    });

    test('un compte e-mail ne produit aucun événement de connexion sociale', () async {
      final FakeCredentialsGateway credentials = FakeCredentialsGateway(
        onLogin: (_, __) => const AuthSession(
          accessToken: 'access',
          userId: 'user-2',
          email: 'apprenant@example.com',
          provider: AuthProvider.email,
        ),
      );
      final FakeAuthTelemetry emailTelemetry = FakeAuthTelemetry();
      final ProviderContainer emailContainer = ProviderContainer(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(FakeAuthGateway()),
          credentialsGatewayProvider.overrideWithValue(credentials),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(true),
          authRequiredProvider.overrideWithValue(true),
          authTelemetryProvider.overrideWithValue(emailTelemetry),
        ],
      );
      addTearDown(emailContainer.dispose);
      emailContainer.read(authControllerProvider);
      await settle();
      await emailContainer
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'apprenant@example.com', password: 'password123');
      credentials.onLogin = (_, __) => throw const AuthGatewayException(
            'E-mail ou mot de passe incorrect.',
            cause: AuthFailureCause.invalidCredentials,
          );

      final SensitiveReauthenticationResult result = await emailContainer
          .read(authControllerProvider.notifier)
          .reauthenticateForAccountDeletion(expectedUserId: 'user-2', password: 'mauvais-mdp');

      expect(result.message, 'E-mail ou mot de passe incorrect.');
      expect(emailTelemetry.failures, isEmpty);
    });
  });
}
