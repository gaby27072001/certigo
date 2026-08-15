import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/presentation/landing_screen.dart';
import 'package:certigo/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Tests d'interface de [LandingScreen] : le hero d'ouverture façon Luma rend
/// sans exception, et le CTA « Commencer » ouvre la bottom sheet d'auth
/// contenant Microsoft / Google / Apple + « e-mail ».
///
/// On ne `pumpAndSettle` jamais : `OrbitField` anime un flottement en boucle et
/// ne se stabiliserait pas.
void main() {
  Future<void> pumpLanding(WidgetTester tester, {bool configured = true}) async {
    // Le hero façon Luma est plus haut que la fenêtre de test par défaut
    // (800x600) : on élargit la surface pour que le CTA, le lien « J'ai déjà un
    // compte » et la sheet soient à l'écran et donc tappables.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(FakeAuthGateway()),
          credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(configured),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: PrismTheme.light(), home: const LandingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('rend le hero (wordmark, titre en deux lignes, CTA)', (WidgetTester tester) async {
    await pumpLanding(tester);

    expect(find.text('Certigo'), findsOneWidget);
    expect(find.text('Tes certifs cloud & IT'), findsOneWidget);
    expect(find.text('commencent ici'), findsOneWidget); // 2ᵉ ligne en dégradé
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.byKey(const Key('landing-existing-account')), findsOneWidget);
  });

  testWidgets('taper « Commencer » ouvre la sheet avec Microsoft/Google/Apple + e-mail', (
    WidgetTester tester,
  ) async {
    await pumpLanding(tester);

    await tester.tap(find.text('Commencer'));
    await tester.pump(); // démarre l'ouverture de la sheet
    await tester.pump(const Duration(milliseconds: 400)); // laisse la sheet apparaître

    // La sheet est ouverte : son titre « Commencer » s'ajoute au CTA.
    expect(find.text('Commencer'), findsNWidgets(2));
    expect(find.byType(AuthProviderButton), findsNWidgets(4));
    expect(find.text('Continuer avec Microsoft'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Continuer avec Apple'), findsOneWidget);
    expect(find.text('Continuer avec un e-mail'), findsOneWidget);
  });

  testWidgets('même sans Entra configuré, la sheet montre les 4 boutons', (
    WidgetTester tester,
  ) async {
    await pumpLanding(tester, configured: false);

    await tester.tap(find.text('Commencer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Les fournisseurs sociaux sont toujours proposés depuis l'écran
    // d'ouverture (la config Entra est vérifiée au moment du tap, pas ici).
    expect(find.byType(AuthProviderButton), findsNWidgets(4));
    expect(find.text('Continuer avec Microsoft'), findsOneWidget);
    expect(find.text('Continuer avec un e-mail'), findsOneWidget);
  });

  testWidgets('le lien « J’ai déjà un compte » ouvre aussi la sheet', (WidgetTester tester) async {
    await pumpLanding(tester);

    await tester.tap(find.byKey(const Key('landing-existing-account')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Continuer avec Microsoft'), findsOneWidget);
  });
}
