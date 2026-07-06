import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/inline_error.dart';
import '../../../shared/widgets/screen_header.dart';

/// Shop — spend hard-earned gems on boosters and streak freezes. Fed by
/// `shopCatalogProvider`. Each purchase carries a client-generated id for
/// idempotency; we disable items the learner cannot afford and, on a successful
/// purchase, invalidate the catalog so the gem balance and any token counts
/// refresh from the server.
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
              child: async.when(
                data: (ShopCatalog catalog) => _ShopContent(catalog: catalog),
                loading: () => const _ShopLoading(),
                error: (Object error, StackTrace _) => PrismStatusView.error(
                  onRetry: () => ref.invalidate(shopCatalogProvider),
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

  Future<void> _buy(ShopItem item) async {
    setState(() {
      _buyingId = item.id;
      _error = null;
    });
    final Result<PurchaseResult> result = await ref.read(shopRepositoryProvider).purchase(
          PurchaseRequest(
            itemId: item.id,
            clientPurchaseId: DateTime.now().microsecondsSinceEpoch.toString(),
          ),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (PurchaseResult r) {
        setState(() {
          _buyingId = null;
          _error = r.success ? null : (r.error ?? 'L\'achat n\'a pas pu être finalisé.');
        });
        if (r.success) {
          ref.invalidate(shopCatalogProvider);
        }
      },
      failure: (Failure f) {
        setState(() {
          _buyingId = null;
          _error = f.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final ShopCatalog catalog = widget.catalog;

    if (catalog.items.isEmpty) {
      return const PrismStatusView(
        icon: Icons.storefront_rounded,
        title: 'Boutique vide',
        message: 'De nouveaux articles arrivent bientôt.',
      );
    }

    return ListView(
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
                  ],
                ),
              ),
              GemCounter(gems: catalog.gems),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 14),
          InlineError(message: _error!),
        ],
        const SizedBox(height: 16),
        for (final ShopItem item in catalog.items) ...<Widget>[
          _ShopItemCard(
            item: item,
            affordable: item.priceGems <= catalog.gems,
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
    required this.affordable,
    required this.buying,
    required this.buyEnabled,
    required this.onBuy,
  });

  final ShopItem item;
  final bool affordable;
  final bool buying;
  final bool buyEnabled;
  final VoidCallback onBuy;

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
                child: Icon(_kindIcon(item.kind), color: p.primary, size: 22),
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
              const Spacer(),
              SizedBox(
                width: 150,
                child: PrismButton(
                  label: affordable ? 'Acheter' : 'Gemmes insuffisantes',
                  icon: affordable ? Icons.shopping_bag_rounded : null,
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

IconData _kindIcon(String kind) {
  return switch (kind) {
    'streak_freeze' || 'freeze' => Icons.ac_unit_rounded,
    'xp_boost' || 'xp' => Icons.bolt_rounded,
    'heart' || 'hearts' => Icons.favorite_rounded,
    'gems' => Icons.diamond_rounded,
    'cosmetic' || 'theme' => Icons.palette_rounded,
    _ => Icons.shopping_bag_rounded,
  };
}
