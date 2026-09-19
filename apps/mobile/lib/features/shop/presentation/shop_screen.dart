import 'dart:math';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../shared/widgets/async_module.dart';
import '../../../shared/widgets/inline_error.dart';
import '../../../shared/widgets/screen_header.dart';

/// Shop — spend hard-earned gems on boosters and streak freezes. Fed by
/// `shopCatalogProvider`. Each purchase carries a client-generated idempotency
/// key that is **held across retries** so a tap replayed after a transport
/// failure resolves to the same server-side purchase instead of debiting the
/// learner twice; we disable items the learner cannot afford and, on a
/// successful purchase, invalidate the catalog so the gem balance and any token
/// counts refresh from the server.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ShopCatalog> async = ref.watch(shopCatalogProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const ScreenHeader(title: 'Boutique'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => refreshQuietly(() => ref.refresh(shopCatalogProvider.future)),
                child: AsyncModule<ShopCatalog>(
                  state: async,
                  errorMessage: ShopLabels.unavailable,
                  onRetry: () => ref.invalidate(shopCatalogProvider),
                  loading: (BuildContext context) => const _ShopLoading(),
                  data: (BuildContext context, ShopCatalog catalog) =>
                      _ShopContent(catalog: catalog),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopContent extends ConsumerStatefulWidget {
  const _ShopContent({required this.catalog});

  final ShopCatalog catalog;

  @override
  ConsumerState<_ShopContent> createState() => _ShopContentState();
}

class _ShopContentState extends ConsumerState<_ShopContent> {
  String? _buyingId;
  String? _error;

  /// Idempotency keys, held per item for as long as the purchase outcome is
  /// unknown. The server dedupes on `clientPurchaseId` (ledger id
  /// `purchase::{clientPurchaseId}`), so a retry after a transport failure —
  /// where the debit may already have been applied — must carry the *same*
  /// key or the learner is charged twice for one item.
  final Map<String, String> _purchaseIds = <String, String>{};

  Future<void> _buy(ShopItem item) async {
    setState(() {
      _buyingId = item.id;
      _error = null;
    });
    final String clientPurchaseId = _purchaseIds.putIfAbsent(item.id, _newPurchaseId);
    final Result<PurchaseResult> result = await ref.read(shopRepositoryProvider).purchase(
          PurchaseRequest(
            itemId: item.id,
            clientPurchaseId: clientPurchaseId,
          ),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (PurchaseResult r) {
        // The server ruled on this key — granted or refused, the outcome is
        // final — so the next purchase of the same item starts a fresh key.
        _purchaseIds.remove(item.id);
        setState(() {
          _buyingId = null;
          _error = r.success ? null : (r.error ?? 'L\'achat n\'a pas pu être finalisé.');
        });
        if (r.success) {
          ref.invalidate(shopCatalogProvider);
          // The purchase granted tokens; refresh the profile so the reserve
          // shown on the balance card matches what the server just recorded.
          ref.invalidate(meProvider);
        }
      },
      failure: (Failure f) {
        // Transport failure: the purchase may or may not have been applied.
        // Keep the key so a retry resolves to that same server-side operation.
        setState(() {
          _buyingId = null;
          _error = f.message;
        });
      },
    );
  }

  static String _newPurchaseId() {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    final int rand = Random().nextInt(0x7fffffff);
    return '${micros.toRadixString(16)}-${rand.toRadixString(16)}';
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final ShopCatalog catalog = widget.catalog;
    // Owned tokens live on the profile, not on the shop payload. Absent while
    // the profile loads (or if it fails) — the shop stays usable either way.
    final int? freezeTokens = ref.watch(meProvider).asData?.value.freezeTokens;

    if (catalog.items.isEmpty) {
      // "Rien n'existe encore" — distinct from "impossible de charger", which
      // the module above resolves, and it names what to do next rather than
      // leaving the learner on a dead end.
      return ScrollableStatus(
        child: PrismStatusView(
          icon: Icons.storefront_rounded,
          title: ShopLabels.emptyTitle,
          message: ShopLabels.emptyMessage,
          actionLabel: ShopLabels.emptyAction,
          actionIcon: Icons.school_rounded,
          onAction: () => context.go(Routes.path),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: <Widget>[
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: p.info,
          child: Row(
            children: <Widget>[
              Icon(Icons.storefront_rounded, color: p.info, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Ton solde', style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Dépense tes gemmes intelligemment.',
                      style: t.bodySmall?.copyWith(color: p.textSecondary),
                    ),
                    if (freezeTokens != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Icon(Icons.ac_unit_rounded, size: 14, color: p.info),
                          const SizedBox(width: 4),
                          Text(
                            _freezeLabel(freezeTokens),
                            style: t.labelMedium?.copyWith(
                              color: p.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              GemCounter(gems: catalog.gems),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[const SizedBox(height: 14), InlineError(message: _error!)],
        const SizedBox(height: 16),
        for (final ShopItem item in catalog.items) ...<Widget>[
          _ShopItemCard(
            item: item,
            gems: catalog.gems,
            buying: _buyingId == item.id,
            buyEnabled: item.priceGems <= catalog.gems && _buyingId == null,
            onBuy: () => _buy(item),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.item,
    required this.gems,
    required this.buying,
    required this.buyEnabled,
    required this.onBuy,
  });

  final ShopItem item;
  final int gems;
  final bool buying;
  final bool buyEnabled;
  final VoidCallback onBuy;

  bool get affordable => item.priceGems <= gems;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.primary.withOpacity(0.14),
                  borderRadius: PrismRadii.cardMd,
                ),
                child: Icon(shopKindIcon(item.kind), color: p.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.name,
                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (item.amount > 1) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            'x${item.amount}',
                            style: t.labelMedium?.copyWith(
                              color: p.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(Icons.diamond_rounded, size: 18, color: affordable ? p.info : p.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${item.priceGems}',
                style: t.titleMedium?.copyWith(
                  color: affordable ? p.textPrimary : p.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              // The shortfall is stated beside the price, where the learner is
              // already looking, and names the exact number missing. It used to
              // be the button's label, which named a state instead of an action
              // and did not fit: "Gemmes insuffisantes" rendered "Gemmes in…"
              // inside a fixed 150 px button.
              if (!affordable) ...<Widget>[
                const SizedBox(width: PrismSpacing.xs),
                Expanded(
                  child: Text(
                    ShopLabels.missing(item.priceGems - gems),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                ),
              ] else
                const Spacer(),
              SizedBox(
                width: 150,
                child: PrismButton(
                  label: ShopLabels.buy,
                  icon: Icons.shopping_bag_rounded,
                  loading: buying,
                  expand: true,
                  onPressed: buyEnabled ? onBuy : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopLoading extends StatelessWidget {
  const _ShopLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: const <Widget>[
        PrismSkeleton(height: 78),
        SizedBox(height: 16),
        PrismSkeleton(height: 150),
        SizedBox(height: 12),
        PrismSkeleton(height: 150),
        SizedBox(height: 12),
        PrismSkeleton(height: 150),
      ],
    );
  }
}

/// Maps a server `kind` to its icon.
///
/// The value arrives as the .NET enum member name — `StreakFreeze` for
/// `ShopItemKind.StreakFreeze` (`GamificationServices.cs:37` calls
/// `i.Kind.ToString()`). Four spellings of that single concept have already
/// existed in this repository at once, so we match a case- and
/// separator-insensitive form instead of an exact literal.
///
/// This protects against a change of *form*, not a change of *name*: if the
/// server ever renamed `StreakFreeze` to `StreakProtection`, the item would
/// fall back to the generic icon — which is the intended behaviour, since a
/// rename is a real change and should be visible rather than absorbed.
IconData shopKindIcon(String kind) {
  return switch (_normalizeKind(kind)) {
    'streakfreeze' || 'freeze' => Icons.ac_unit_rounded,
    'xpboost' || 'xp' => Icons.bolt_rounded,
    'heart' || 'hearts' => Icons.favorite_rounded,
    'gems' => Icons.diamond_rounded,
    'cosmetic' || 'theme' => Icons.palette_rounded,
    _ => Icons.shopping_bag_rounded,
  };
}

String _normalizeKind(String kind) => kind.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

String _freezeLabel(int tokens) =>
    tokens > 1 ? '$tokens gels de série en réserve' : '$tokens gel de série en réserve';

/// Copy asserted by tests. Named so a wording change cannot silently turn a
/// widget test red from an unrelated branch.
abstract final class ShopLabels {
  static const String buy = 'Acheter';

  static const String unavailable = 'Impossible de charger la boutique.';
  static const String emptyTitle = 'Boutique vide';
  static const String emptyMessage =
      'De nouveaux articles arrivent bientôt. En attendant, tes gemmes continuent de monter.';
  static const String emptyAction = 'Gagner des gemmes';

  /// How many gems are still missing. The button names its action; this names
  /// the obstacle, precisely, next to the price it refers to.
  static String missing(int gems) => 'il te manque $gems';
}
