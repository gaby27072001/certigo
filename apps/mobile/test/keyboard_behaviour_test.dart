import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/register_draft.dart';
import 'package:certigo/features/auth/presentation/register_name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Garde de **comportement natif** : le clavier.
///
/// Trois défauts font qu'un formulaire « ne se sent pas natif » sur iPhone :
/// le clavier masque le champ qu'on remplit, la touche « suivant » ne passe pas
/// au champ d'après, et le bouton principal disparaît sous le clavier.
///
/// Ces trois points ont été **mesurés sur le parcours d'inscription réel** et
/// s'y comportent correctement. Ce fichier ne corrige donc rien : il empêche la
/// régression, parce que chacun de ces trois points se casse d'une seule ligne
/// et ne se voit qu'à l'usage, sur un appareil.
void main() {
  /// Hauteur du clavier iOS en points, iPhone 15 Pro, clavier alphabétique
  /// avec barre de suggestions.
  const double kKeyboardHeight = 336;

  Future<void> pumpRegisterName(WidgetTester tester, {double keyboard = 0}) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(FakeAuthGateway()),
        credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
        sessionStoreProvider.overrideWithValue(FakeSessionStore()),
        authRequiredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    container.read(registerDraftProvider.notifier);

    final GoRouter router = GoRouter(
      initialLocation: '/register/name',
      routes: <RouteBase>[
        GoRoute(path: '/register/name', builder: (_, __) => const RegisterNameScreen()),
        GoRoute(path: '/register/email', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/landing', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/auth', builder: (_, __) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  /// Lit le `FocusNode` **propre** au champ.
  ///
  /// Une première version lisait `Focus.of(context, scopeOk: true)`, qui remonte
  /// au `Focus` **ancêtre** — partagé par les deux champs. Elle rendait `true`
  /// pour les deux, avant comme après l'appui sur « suivant » : un instrument
  /// qui ne pouvait pas distinguer les deux réponses, donc qui n'en mesurait
  /// aucune. Voir `docs/GOVERNANCE.md` §7.
  bool hasFocus(WidgetTester tester, Finder field) {
    final EditableText editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    return editable.focusNode.hasFocus;
  }

  void useIPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  final Finder firstName = find.byKey(const Key('register-first-name'));
  final Finder lastName = find.byKey(const Key('register-last-name'));

  testWidgets('le premier champ prend le focus tout seul', (WidgetTester tester) async {
    useIPhone(tester);
    await pumpRegisterName(tester);

    expect(hasFocus(tester, firstName), isTrue);
    expect(
      hasFocus(tester, lastName),
      isFalse,
      reason: 'Deux champs focalisés en même temps signalerait un instrument '
          'qui lit le mauvais nœud, pas un écran correct.',
    );
  });

  testWidgets('« suivant » passe au champ d\'après', (WidgetTester tester) async {
    useIPhone(tester);
    await pumpRegisterName(tester);

    await tester.tap(firstName);
    await tester.pump();
    expect(hasFocus(tester, firstName), isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(
      hasFocus(tester, lastName),
      isTrue,
      reason: 'Sans enchaînement, il faut viser le champ suivant au doigt — le '
          'marqueur le plus banal d\'un formulaire porté à la va-vite.',
    );
    expect(hasFocus(tester, firstName), isFalse);
  });

  testWidgets('le clavier ne masque ni les champs ni le bouton principal',
      (WidgetTester tester) async {
    useIPhone(tester);
    await pumpRegisterName(tester, keyboard: kKeyboardHeight);

    final double screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final double keyboardTop = screenHeight - kKeyboardHeight;

    for (final MapEntry<String, Finder> target in <String, Finder>{
      'le prénom': firstName,
      'le nom': lastName,
      'le bouton Continuer': find.text('Continuer'),
    }.entries) {
      expect(
        target.value,
        findsWidgets,
        reason: 'Si ${target.key} est introuvable, ce test ne mesure rien.',
      );
      expect(
        tester.getRect(target.value.first).bottom,
        lessThanOrEqualTo(keyboardTop),
        reason: '${target.key} passe sous le clavier : bas à '
            '${tester.getRect(target.value.first).bottom}, le clavier commence '
            'à $keyboardTop.',
      );
    }
  });

  testWidgets('sans clavier, le bouton principal descend bien en bas', (WidgetTester tester) async {
    // Témoin : si le bouton était au même endroit avec et sans clavier, le test
    // ci-dessus passerait sans rien prouver — il ne verrait pas le clavier.
    useIPhone(tester);
    await pumpRegisterName(tester);
    final double restingBottom = tester.getRect(find.text('Continuer').first).bottom;

    await pumpRegisterName(tester, keyboard: kKeyboardHeight);
    final double liftedBottom = tester.getRect(find.text('Continuer').first).bottom;

    expect(
      liftedBottom,
      lessThan(restingBottom),
      reason: 'Le bouton doit remonter au-dessus du clavier. S\'il ne bouge '
          'pas, la mise en page ignore `viewInsets` et la mesure précédente '
          'est sans valeur.',
    );
  });
}
