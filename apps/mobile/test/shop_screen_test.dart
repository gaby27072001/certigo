import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/shop/presentation/shop_screen.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/fake_user_repository.dart';

/// Widget test for [ShopScreen].
///
/// The screen is presented above the app shell and reads the catalog from
/// [shopCatalogProvider]; here we override that provider with a deterministic
/// fake and host the screen under a one-route [GoRouter] so we can assert it
/// renders the header, the balance label and an individual item. We never call
/// [WidgetTester.pumpAndSettle] — the aurora background never settles.
void main() {
  ShopCatalog fakeCatalog() => const ShopCatalog(
        gems: 50,
        items: <ShopItem>[
          ShopItem(
            id: 'freeze',
            name: 'Gel de série',
            description: 'Protège ta série un jour sans activité.',
            priceGems: 30,
            kind: 'StreakFreeze',
            amount: 1,
          ),
        ],
      );

  Future<void> pumpShop(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/shop',
      routes: <RouteBase>[
        GoRoute(
          path: '/shop',
          builder: (BuildContext context, GoRouterState state) => const ShopScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          shopCatalogProvider.overrideWith((Ref ref) async => fakeCatalog()),
          meProvider.overrideWith((Ref ref) async => testUserProfile()),
        ],
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the header, the balance label and an item', (tester) async {
    await pumpShop(tester);

    expect(find.text('Boutique'), findsOneWidget);
    expect(find.text('Ton solde'), findsOneWidget);
    expect(find.text('Gel de série'), findsOneWidget);
  });

  testWidgets('shows the freeze reserve the learner already owns', (tester) async {
    await pumpShop(tester);

    // The token is credited by the server and consumed automatically by
    // StreakService.UpdateStreak; before this it was never shown anywhere, so
    // the learner bought something they could not see.
    expect(find.text('1 gel de série en réserve'), findsOneWidget);
  });

  testWidgets('renders the server icon for the streak freeze', (tester) async {
    await pumpShop(tester);

    // The item card icon is size 22 — distinct from the reserve badge (14) and
    // from the buy button's bag, so this asserts the card itself resolved the
    // server's `StreakFreeze` rather than falling through to the generic icon.
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == Icons.ac_unit_rounded && w.size == 22,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == Icons.shopping_bag_rounded && w.size == 22,
      ),
      findsNothing,
    );
  });
}
