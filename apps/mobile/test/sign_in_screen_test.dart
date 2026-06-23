import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microlingo/features/auth/application/auth_controller.dart';
import 'package:microlingo/features/auth/application/auth_state.dart';
import 'package:microlingo/features/auth/presentation/sign_in_screen.dart';
import 'package:microlingo/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeSessionStore;

/// Tests d'interface de [SignInScreen] : présence des **trois** boutons de
/// connexion et déclenchement du flux du bon fournisseur au tap.
///
/// On ne `pumpAndSettle` jamais : l'[AuroraBackground] anime en boucle et ne se
/// stabiliserait jamais.
void main() {
  Future<void> pumpSignIn(
    WidgetTester tester, {
    required FakeAuthGateway gateway,
    required FakeSessionStore store,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(gateway),
          sessionStoreProvider.overrideWithValue(store),
          authConfiguredProvider.overrideWithValue(true),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: PrismTheme.light(),
          home: const SignInScreen(),
        ),
      ),
    );
    // Laisse la restauration différée se résoudre (aucune session → écran de
    // connexion), puis une frame courte de mise en page.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('présente les trois boutons Microsoft, Google et Apple', (tester) async {
    await pumpSignIn(tester, gateway: FakeAuthGateway(), store: FakeSessionStore());

    expect(find.text('Microlingo'), findsOneWidget);
    expect(find.byType(AuthProviderButton), findsNWidgets(3));
    expect(find.text('Continuer avec Microsoft'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Continuer avec Apple'), findsOneWidget);
  });

  testWidgets('le tap sur un fournisseur déclenche sa connexion', (tester) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      onSignIn: (AuthProvider provider) => AuthSession(
        accessToken: 'jeton',
        provider: provider,
      ),
    );
    final FakeSessionStore store = FakeSessionStore();
    await pumpSignIn(tester, gateway: gateway, store: store);

    await tester.tap(find.text('Continuer avec Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(gateway.signInCalls, <AuthProvider>[AuthProvider.google]);
    // La session a bien été persistée → l'app se rouvrira dessus.
    expect(store.writeCalls, 1);
  });
}
