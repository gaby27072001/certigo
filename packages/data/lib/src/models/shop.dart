/// The gem shop. A small catalog of consumables (streak freezes, etc.) the
/// learner buys with gems. Purchases are idempotent via [clientPurchaseId] so a
/// retried tap never double-charges.
library;

/// One purchasable shop item.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceGems,
    required this.kind,
    required this.amount,
  });

  final String id;
  final String name;
  final String description;
  final int priceGems;
  final String kind;
  final int amount;

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        priceGems: (json['priceGems'] as num?)?.toInt() ?? 0,
        kind: json['kind'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
      );
}

/// The shop catalog plus the learner's current gem balance.
class ShopCatalog {
  const ShopCatalog({required this.gems, required this.items});

  final int gems;
  final List<ShopItem> items;

  factory ShopCatalog.fromJson(Map<String, dynamic> json) => ShopCatalog(
        gems: (json['gems'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Request body for `POST /shop/purchase`.
class PurchaseRequest {
  const PurchaseRequest({required this.itemId, required this.clientPurchaseId});

  final String itemId;
  final String clientPurchaseId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'itemId': itemId,
        'clientPurchaseId': clientPurchaseId,
      };
}

/// Server result of a purchase: the new gem balance and any granted tokens.
class PurchaseResult {
  const PurchaseResult({
    required this.success,
    required this.itemId,
    required this.gemsSpent,
    required this.gemsBalance,
    required this.freezeTokens,
    this.error,
  });

  final bool success;
  final String itemId;
  final int gemsSpent;
  final int gemsBalance;
  final int freezeTokens;
  final String? error;

  factory PurchaseResult.fromJson(Map<String, dynamic> json) => PurchaseResult(
        success: json['success'] as bool? ?? false,
        itemId: json['itemId'] as String? ?? '',
        gemsSpent: (json['gemsSpent'] as num?)?.toInt() ?? 0,
        gemsBalance: (json['gemsBalance'] as num?)?.toInt() ?? 0,
        freezeTokens: (json['freezeTokens'] as num?)?.toInt() ?? 0,
        error: json['error'] as String?,
      );
}
