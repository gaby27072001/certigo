import 'package:certigo/app/app.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_diagnostics.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/presentation/register_name_screen.dart';
import 'package:certigo/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;
import 'support/error_message.dart';
import 'support/prism_fonts.dart';

/// Parcours signalé le 2026-09-25 sur iPhone : « Continuer avec Apple » échoue,
/// puis « J’ai déjà un compte » → « Continuer avec un e-mail ».
///
/// Rejoué sur l'application **réelle** — [CertigoApp], donc `routerProvider`,
/// sa table de routes et `resolveAuthRedirect` — et non sur un routeur de test
/// dont les cibles seraient des maquettes : c'est la table réelle qui décide si
/// l'e-mail ouvre la connexion ou l'inscription.
///
/// La build TestFlight concernée précède #448 (l'e-mail menait à
/// `/register/name`) et #505 (le journal d'étapes Apple et un
/// `[technique] PlatformException…` s'affichaient sur la page de connexion).
/// Sur `main`, l'écran de connexion reprenait encore l'échec Apple comme s'il
/// était le sien, et un build sans Entra montrait un nom de variable de build.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPrismFonts);
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// iPhone 14/15/16 : 390×844 points à 3×.
  void sizeIPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required FakeAuthGateway gateway,
    FakeCredentialsGateway? credentials,
    bool configured = true,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(gateway),
        credentialsGatewayProvider.overrideWithValue(credentials ?? FakeCredentialsGateway()),
        sessionStoreProvider.overrideWithValue(FakeSessionStore()),
        authConfiguredProvider.overrideWithValue(configured),
        authRequiredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CertigoApp()),
    );
    // Restauration sans session → `Unauthenticated` → `/landing`. L'orbite de
    // l'accueil anime en boucle : on avance par frames, jamais `pumpAndSettle`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    return container;
  }

  Future<void> tapAndWait(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
    // Assez pour qu'une transition de page iOS se termine : pendant qu'elle
    // joue, l'écran quitté est encore dans l'arbre.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openExistingAccountSheet(WidgetTester tester) =>
      tapAndWait(tester, find.byKey(const Key('landing-existing-account')));

  /// Ce que fait la feuille après un échec social (rester ouverte ou se fermer)
  /// est traité à part : ces tests ne dépendent ni de l'un ni de l'autre.
  Future<void> closeSheetIfOpen(WidgetTester tester) async {
    final Finder close = find.byKey(const Key('get-started-close'));
    if (close.evaluate().isNotEmpty) await tapAndWait(tester, close);
  }

  testWidgets(
    'après un échec Apple, « J’ai déjà un compte » → e-mail ouvre la connexion, '
    'sans l’échec hérité ni journal technique',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      sizeIPhone(tester);
      final ProviderContainer container = await pumpApp(
        tester,
        gateway: FakeAuthGateway(
          onSignIn: (_) => throw StateError('ASWebAuthenticationSession sans callback'),
        ),
      );

      await openExistingAccountSheet(tester);
      await tapAndWait(tester, find.text('Continuer avec Apple'));

      // L'échec Apple a bien laissé un message global ET une trace d'étapes :
      // ce sont eux qui s'affichaient sur la page de connexion.
      final AuthState afterApple = container.read(authControllerProvider);
      expect(afterApple, isA<Unauthenticated>());
      final String appleFailure = (afterApple as Unauthenticated).message ?? '';
      expect(appleFailure, isNotEmpty);
      expect(container.read(authDiagnosticsProvider), isNotEmpty);

      // Comme Gabriel : retour à l'accueil, puis « J'ai déjà un compte » → e-mail.
      await closeSheetIfOpen(tester);
      await openExistingAccountSheet(tester);
      await tapAndWait(tester, find.text('Continuer avec un e-mail'));

      // La CONNEXION, pas l'inscription « Comment tu t'appelles ? ».
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(RegisterNameScreen), findsNothing);
      expect(find.text('Content de te revoir'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
      expect(find.byKey(const Key('register-first-name')), findsNothing);

      // Rien de la tentative Apple : ni carte d'échec, ni journal d'étapes.
      expect(find.byKey(const Key('auth-error')), findsNothing);
      expect(find.byKey(const Key('auth-diagnostic')), findsNothing);
      expect(find.text(appleFailure), findsNothing);
      expectNoTechnicalText(tester, context: 'connexion e-mail après un échec Apple');

      // VoiceOver annonce les champs par leur nom, et pas la lettre du logo.
      expect(find.bySemanticsLabel('E-mail'), findsOneWidget);
      expect(find.bySemanticsLabel('Mot de passe'), findsOneWidget);
      expect(find.bySemanticsLabel('C'), findsNothing);

      // VoiceOver et zones de toucher de 44 pt sur l'écran atteint.
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'sur cette connexion, un mauvais mot de passe dit la cause, sans détail technique',
    (WidgetTester tester) async {
      sizeIPhone(tester);
      await pumpApp(
        tester,
        gateway: FakeAuthGateway(),
        credentials: FakeCredentialsGateway(
          onLogin: (_, __) => throw const AuthGatewayException(
            'E-mail ou mot de passe incorrect.',
            cause: AuthFailureCause.invalidCredentials,
            diagnostic: 'HTTP 401 POST /auth/login',
          ),
        ),
      );

      await openExistingAccountSheet(tester);
      await tapAndWait(tester, find.text('Continuer avec un e-mail'));
      expect(find.byType(SignInScreen), findsOneWidget);

      await tester.enterText(find.byKey(const Key('email-field')), 'apprenant@example.com');
      await tester.enterText(find.byKey(const Key('password-field')), 'mauvais-mdp');
      await tapAndWait(tester, find.byKey(const Key('email-submit')));

      // L'écran reste celui de la connexion, et dit pourquoi.
      expect(find.byType(SignInScreen), findsOneWidget);
      final Finder card = find.byKey(const Key('auth-error'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('E-mail ou mot de passe incorrect.')),
        findsOneWidget,
      );
      expectNoTechnicalText(tester, context: 'connexion e-mail refusée');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'sans Entra, « Continuer avec Apple » renvoie vers l’e-mail sans nom de variable de build',
    (WidgetTester tester) async {
      sizeIPhone(tester);
      final ProviderContainer container =
          await pumpApp(tester, gateway: FakeAuthGateway(), configured: false);

      await openExistingAccountSheet(tester);
      await tapAndWait(tester, find.text('Continuer avec Apple'));

      // L'échec s'affiche (dans la feuille ou sur l'accueil) et dit quoi faire,
      // sans nom de variable de build.
      final String failure =
          (container.read(authControllerProvider) as Unauthenticated).message ?? '';
      expect(failure, contains('e-mail'));
      expect(find.text(failure), findsWidgets);
      expect(find.textContaining('diagnostic'), findsNothing);
      expectNoTechnicalText(tester, context: 'après Apple, build sans Entra');

      // Et l'écran e-mail qui suit ne reprend pas cet échec à son compte.
      await closeSheetIfOpen(tester);
      await openExistingAccountSheet(tester);
      await tapAndWait(tester, find.text('Continuer avec un e-mail'));
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byKey(const Key('auth-error')), findsNothing);
      expect(find.text(failure), findsNothing);
      expectNoTechnicalText(tester, context: 'connexion e-mail, build sans Entra');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final double scale in <double>[1.0, 2.0, 3.0]) {
    testWidgets(
      'Dynamic Type ×$scale : la connexion e-mail reflue sans déborder, tronquer, rogner '
      'ni couper un mot',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authGatewayProvider.overrideWithValue(FakeAuthGateway()),
              credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
              sessionStoreProvider.overrideWithValue(FakeSessionStore()),
              authConfiguredProvider.overrideWithValue(true),
              authRequiredProvider.overrideWithValue(true),
            ],
            child: MaterialApp(
              theme: PrismTheme.light(),
              builder: (BuildContext context, Widget? child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const SignInScreen(emailOnly: true),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull, reason: 'débordement à ×$scale');
        for (final RenderObject node in tester.allRenderObjects) {
          if (node is! RenderParagraph) continue;
          final String label = node.text.toPlainText();
          expect(node.didExceedMaxLines, isFalse, reason: '« $label » tronqué à ×$scale');
          expect(
            breaksInsideAWord(node),
            isFalse,
            reason: '« $label » coupé en plein mot à ×$scale',
          );
          // Mesuré à ×2 avant correctif : le « C » du badge demandait 78 px
          // dans un cadre de 49 px, et le cadre le rognait.
          final double needed = node.getMinIntrinsicHeight(node.size.width);
          expect(
            needed,
            lessThanOrEqualTo(node.size.height + 0.5),
            reason: '« $label » rogné à ×$scale : ${needed.toStringAsFixed(1)} px '
                'de texte dans ${node.size.height.toStringAsFixed(1)} px',
          );
        }

        // L'action principale reste atteignable par défilement.
        final Finder submit = find.byKey(const Key('email-submit'));
        await tester.ensureVisible(submit);
        await tester.pump();
        final Rect box = tester.getRect(submit);
        expect(box.top, greaterThanOrEqualTo(0));
        expect(box.bottom, lessThanOrEqualTo(844));
        expect(box.height, greaterThanOrEqualTo(44));
      },
    );
  }
}

/// Vrai si [paragraph] passe à la ligne ailleurs qu'entre deux mots : Flutter
/// coupe un mot plus large que la ligne au lieu de le laisser déborder, et
/// `didExceedMaxLines` ne le voit pas.
bool breaksInsideAWord(RenderParagraph paragraph) {
  final String text = paragraph.text.toPlainText();
  final RegExp boundary = RegExp(r'[\s\-‐–—/]');
  double? previousTop;
  for (int i = 0; i < text.length; i++) {
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    final double top = boxes.first.top;
    if (previousTop != null &&
        top > previousTop + 0.5 &&
        !boundary.hasMatch(text[i - 1]) &&
        !boundary.hasMatch(text[i])) {
      return true;
    }
    previousTop = top;
  }
  return false;
}
