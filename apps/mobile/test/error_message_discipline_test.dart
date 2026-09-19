import 'package:certigo/app/providers.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/presentation/sign_in_screen.dart';
import 'package:certigo/features/library/presentation/certification_chapters_screen.dart';
import 'package:certigo/features/library/presentation/vendor_certifications_screen.dart';
import 'package:certigo/shared/errors/error_copy.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;
import 'support/error_message.dart';
import 'support/technical_shape.dart';

/// Garde : **aucun détail technique brut ne doit atteindre un widget**, et
/// **aucun état d'erreur ne doit se taire**.
///
/// ## Pourquoi cette garde n'est pas une décoration
///
/// Vérifier l'absence d'une chaîne précise ne prouverait rien : il suffirait de
/// changer cette chaîne pour repasser au vert. C'est la **forme** d'un détail
/// technique qui est attrapée ici (`…Exception`, `code=…`, `errno =`,
/// `[technique]`, `Erreur 500`, une trame de pile, un `Instance of '…'`), via
/// [technicalShapeIn].
///
/// Le détecteur est lui-même épinglé des **deux côtés** (voir
/// `support/technical_shape.dart` et le groupe « le détecteur mord ») :
/// l'affaiblir fait rougir le corpus technique, le durcir fait rougir la copie
/// propre de l'application. On ne peut donc pas neutraliser la garde en
/// retouchant discrètement le motif.
///
/// Et chaque écran est vérifié sur **deux** exigences opposées, pour qu'on ne
/// puisse pas passer au vert en n'affichant rien :
///   1. aucun texte rendu n'a la forme d'un détail technique ;
///   2. un message actionnable **non vide** est bien rendu.
void main() {
  /// Exigence 2 : l'écran dit quand même quelque chose d'actionnable. Sans
  /// elle, supprimer le message suffirait à passer la garde.
  void expectActionableText(WidgetTester tester, {required String context}) {
    final List<String> texts = renderedText(tester)
        .map((String t) => t.trim())
        .where((String t) => t.length >= 20)
        .toList();
    expect(
      texts,
      isNotEmpty,
      reason: '$context : aucun message d\u2019au moins 20 caractères n\u2019est rendu. '
          'Un état d\u2019erreur muet échoue à dire quoi faire, tout autant '
          'qu\u2019un état bavard de technique.',
    );
  }

  group('le détecteur mord (sinon la garde est une décoration)', () {
    for (final ({String label, String sample}) probe in technicalCorpus) {
      test('détecte ${probe.label}', () {
        expect(
          technicalShapeIn(probe.sample),
          isNotNull,
          reason: 'motif affaibli : « ${probe.sample} » passe désormais pour propre',
        );
      });
    }

    // L'autre bord : un détecteur trop large rendrait la garde inutilisable et
    // pousserait à l'affaiblir. La copie que l'app affiche vraiment doit passer.
    for (final ErrorKind kind in ErrorKind.values) {
      for (final ErrorSubject subject in ErrorSubject.values) {
        test('laisse passer la copie propre de $kind / $subject', () {
          final ErrorCopy copy = copyFor(kind, subject: subject);
          expect(technicalShapeIn(copy.title), isNull);
          expect(technicalShapeIn(copy.message), isNull);
          expect(technicalShapeIn(copy.actionLabel), isNull);
        });
      }
    }
  });

  group('la couche de traduction dit toujours quoi faire', () {
    for (final ({String name, Failure failure}) probe in realisticFailures) {
      test('${probe.name} → une cause et une action, jamais le texte brut', () {
        final ErrorCopy copy = describeFailure(
          probe.failure,
          subject: ErrorSubject.catalogue,
        );
        expect(technicalShapeIn(copy.message), isNull);
        expect(technicalShapeIn(copy.title), isNull);
        expect(copy.message.trim(), isNotEmpty);
        expect(copy.actionLabel.trim(), isNotEmpty);
      });
    }

    test('la copie est invariante au texte porté par l\u2019échec', () {
      // Preuve **directe** que la couche ne lit pas `failure.message` : deux
      // échecs de même type dont les textes n'ont rien en commun produisent
      // exactement la même copie. Vérifier une non-occurrence de chaîne ne
      // prouverait pas cela — une coïncidence suffirait à la faire rougir, et
      // un simple renommage à la faire passer.
      const List<(Failure, Failure)> pairs = <(Failure, Failure)>[
        (
          ServerFailure('Erreur serveur', statusCode: 500),
          ServerFailure(
            'Unhandled exception: NullReferenceException at Certigo.Api.Functions',
            statusCode: 500,
          ),
        ),
        (
          NotFoundFailure(),
          NotFoundFailure('#0 ApiClient._guard (package:data/src/api/api_client.dart:220:7)'),
        ),
        (AuthFailure(), AuthFailure('PlatformException code=401 msg=token expired')),
        (ParseFailure(), ParseFailure('Expected a JSON object')),
        (UnknownFailure(), UnknownFailure('Instance of \'_Exception\'')),
        (NetworkFailure(), NetworkFailure('OS Error: errno = 8')),
        (CacheFailure(), CacheFailure('HiveError: box not open')),
      ];
      for (final (Failure clean, Failure noisy) in pairs) {
        final ErrorCopy a = describeFailure(clean, subject: ErrorSubject.catalogue);
        final ErrorCopy b = describeFailure(noisy, subject: ErrorSubject.catalogue);
        expect(
          b.message,
          a.message,
          reason: '${noisy.runtimeType} : le texte de l\u2019échec a influencé la copie',
        );
        expect(b.title, a.title);
        expect(b.kind, a.kind);
      }
    });

    test('une exception nue n\u2019est jamais rendue telle quelle', () {
      final ErrorCopy copy = describeFailure(
        StateError('boom at package:certigo/app/providers.dart:648'),
      );
      expect(copy.kind, ErrorKind.unexpected);
      expect(technicalShapeIn(copy.message), isNull);
    });

    test('le délai de RÉPONSE n\u2019accuse pas un réseau qui a fait ses preuves', () {
      final ErrorCopy copy = describeFailure(const NetworkFailure.responseTimeout());
      expect(copy.kind, ErrorKind.serverSilent);
      expect(copy.message, isNot(contains('Wi-Fi')));
      expect(copy.message, contains('serveur'));
    });

    test('un bouton de navigation ne porte pas l\u2019icône de rafraîchissement', () {
      final ErrorCopy copy = describeFailure(const NotFoundFailure());
      expect(copy.actionLabel, 'Voir la bibliothèque');
      expect(copy.actionIcon, isNot(Icons.refresh_rounded));
    });
  });

  group('VendorCertificationsScreen', () {
    for (final ({String name, Failure failure}) probe in realisticFailures) {
      testWidgets('${probe.name} : cause + action, sans technique', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              catalogProvider.overrideWith((Ref ref) async => throw probe.failure),
            ],
            child: MaterialApp(
              theme: PrismTheme.light(),
              home: const VendorCertificationsScreen(vendor: VendorBrand.microsoft),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        expectNoTechnicalText(tester, context: 'catalogue / ${probe.name}');
        expectActionableText(tester, context: 'catalogue / ${probe.name}');
      });
    }
  });

  group('CertificationChaptersScreen', () {
    for (final ({String name, Failure failure}) probe in realisticFailures) {
      testWidgets('${probe.name} : cause + action, sans technique', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              pathProvider('az-900').overrideWith((Ref ref) async => throw probe.failure),
            ],
            child: MaterialApp(
              theme: PrismTheme.light(),
              home: const CertificationChaptersScreen(trackId: 'az-900'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        expectNoTechnicalText(tester, context: 'chapitres / ${probe.name}');
        expectActionableText(tester, context: 'chapitres / ${probe.name}');
      });
    }
  });

  group('SignInScreen', () {
    // Ce que la passerelle OIDC fabrique réellement : un message convivial
    // **plus** un détail technique brut. Le contrôleur les concaténait.
    final List<({String name, Object error})> authFailures = <({String name, Object error})>[
      (
        name: 'PlatformException flutter_appauth',
        error: const AuthGatewayException(
          'La connexion via microsoft a échoué. Vérifiez la configuration Entra puis réessayez.',
          cause: AuthFailureCause.providerError,
          diagnostic: 'PlatformException code=authorize_and_exchange_code_failed '
              'msg=Failed to authorize details=Error Domain=org.openid.appauth.general Code=-3',
        ),
      ),
      (
        name: 'callback sans code',
        error: const AuthGatewayException(
          'La connexion n\'a pas renvoyé de code d\'autorisation.',
          cause: AuthFailureCause.providerError,
          diagnostic: 'authorize() est revenu sans authorizationCode',
        ),
      ),
      (
        name: 'erreur inattendue',
        error: const AuthGatewayException(
          'La connexion via google a échoué. Vérifiez la configuration Entra puis réessayez.',
          cause: AuthFailureCause.providerError,
          diagnostic: 'MissingPluginException : No implementation found for method authorize',
        ),
      ),
      (name: 'erreur nue non typée', error: StateError('signIn non câblé')),
    ];

    for (final ({String name, Object error}) probe in authFailures) {
      testWidgets('${probe.name} : le détail technique reste hors de l\u2019écran', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final FakeAuthGateway gateway = FakeAuthGateway(
          onSignIn: (AuthProvider _) => throw probe.error,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authGatewayProvider.overrideWithValue(gateway),
              credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
              sessionStoreProvider.overrideWithValue(FakeSessionStore()),
              authConfiguredProvider.overrideWithValue(true),
              authRequiredProvider.overrideWithValue(true),
            ],
            child: MaterialApp(theme: PrismTheme.light(), home: const SignInScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.text('Continuer avec Microsoft'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        expect(
          find.byKey(const Key('auth-error')),
          findsOneWidget,
          reason: 'un échec de connexion doit rester visible et dire quoi faire',
        );
        expectNoTechnicalText(tester, context: 'connexion / ${probe.name}');
        expectActionableText(tester, context: 'connexion / ${probe.name}');
      });
    }
  });
}
