import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/shop/presentation/shop_screen.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/fake_user_repository.dart';

/// Purchase idempotency for [ShopScreen].
///
/// The server dedupes a purchase on `clientPurchaseId` (ledger id
/// `purchase::{clientPurchaseId}`), so the *client* owns the guarantee: it has
/// to replay the same key when it retries. These tests drive the real screen
/// through the real `shopRepositoryProvider` seam and assert on the keys that
/// actually reach the repository — if the screen ever goes back to minting a
/// key per tap, the first test fails.
///
/// The fixture mirrors the real server catalog on purpose
/// (`backend/src/Certigo.Domain/Gamification/ShopCatalog.cs`), including the
/// `kind` string the API actually emits — `ShopItemKind.StreakFreeze.ToString()`
/// in `GamificationServices.cs:37` — so the test cannot pass against a format
/// the server never sends.
void main() {
  const ShopCatalog catalog = ShopCatalog(
    gems: 300,
    items: <ShopItem>[
      ShopItem(
        id: 'streak-freeze',
        name: 'Gel de série',
        description: 'Protège ta série pendant un jour d\'absence.',
        priceGems: 200,
        kind: 'StreakFreeze',
        amount: 1,
      ),
    ],
  );

  const PurchaseResult granted = PurchaseResult(
    success: true,
    itemId: 'streak-freeze',
    gemsSpent: 200,
    gemsBalance: 100,
    freezeTokens: 1,
  );

  const PurchaseResult refused = PurchaseResult(
    success: false,
    itemId: 'streak-freeze',
    gemsSpent: 0,
    gemsBalance: 300,
    freezeTokens: 3,
    error: 'alreadyAtMax',
  );

  Future<void> pumpShop(WidgetTester tester, _RecordingShopRepository repo) async {
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
          shopRepositoryProvider.overrideWith((Ref ref) => repo),
          meProvider.overrideWith((Ref ref) async => testUserProfile()),
        ],
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tapBuy(WidgetTester tester) async {
    await tester.tap(find.text('Acheter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a retried purchase replays the same key', (tester) async {
    final _RecordingShopRepository repo = _RecordingShopRepository(catalog)
      ..enqueue(const Err<PurchaseResult>(NetworkFailure()))
      ..enqueue(const Success<PurchaseResult>(granted));

    await pumpShop(tester, repo);
    await tapBuy(tester);
    await tapBuy(tester);

    // The debit may already have been applied server-side when the transport
    // failed, so the retry has to resolve to that same operation. Minting a new
    // key here is a second purchase, and the learner pays twice for one item.
    expect(repo.requests, hasLength(2));
    expect(repo.requests[1].clientPurchaseId, repo.requests[0].clientPurchaseId);
  });

  testWidgets('a granted purchase starts a fresh key', (tester) async {
    final _RecordingShopRepository repo = _RecordingShopRepository(catalog)
      ..enqueue(const Success<PurchaseResult>(granted))
      ..enqueue(const Success<PurchaseResult>(granted));

    await pumpShop(tester, repo);
    await tapBuy(tester);
    await tapBuy(tester);

    // Otherwise a deliberate second purchase is swallowed as a replay of the
    // first, and the learner gets one item for two taps.
    expect(repo.requests, hasLength(2));
    expect(repo.requests[1].clientPurchaseId, isNot(repo.requests[0].clientPurchaseId));
  });

  testWidgets('a refused purchase starts a fresh key', (tester) async {
    final _RecordingShopRepository repo = _RecordingShopRepository(catalog)
      ..enqueue(const Success<PurchaseResult>(refused))
      ..enqueue(const Success<PurchaseResult>(granted));

    await pumpShop(tester, repo);
    await tapBuy(tester);
    await tapBuy(tester);

    // A refusal is a server ruling, not an unknown: the key is spent.
    expect(repo.requests, hasLength(2));
    expect(repo.requests[1].clientPurchaseId, isNot(repo.requests[0].clientPurchaseId));
  });
}

/// Records every [PurchaseRequest] the screen issues and replays a scripted
/// sequence of outcomes, so the assertions are about the keys the screen
/// actually sends rather than about its internal state.
class _RecordingShopRepository implements ShopRepository {
  _RecordingShopRepository(this._catalog);

  final ShopCatalog _catalog;
  final List<PurchaseRequest> requests = <PurchaseRequest>[];
  final List<Result<PurchaseResult>> _outcomes = <Result<PurchaseResult>>[];

  void enqueue(Result<PurchaseResult> outcome) => _outcomes.add(outcome);

  @override
  Future<Result<ShopCatalog>> getShop() async => Success<ShopCatalog>(_catalog);

  @override
  Future<Result<PurchaseResult>> purchase(PurchaseRequest request) async {
    requests.add(request);
    if (_outcomes.isEmpty) {
      return const Err<PurchaseResult>(UnknownFailure('no scripted outcome left'));
    }
    return _outcomes.removeAt(0);
  }
}
