import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/shop/presentation/shop_screen.dart';
import 'package:prism_ui/prism_ui.dart';

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
            kind: 'streakFreeze',
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
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
        ),
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
}
