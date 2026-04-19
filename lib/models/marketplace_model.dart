class MarketplaceOffer {
  const MarketplaceOffer({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.title,
    required this.description,
    required this.category,
    required this.costFet,
    required this.deliveryType,
    required this.isActive,
    this.partnerLogoUrl,
    this.imageUrl,
    this.originalValue,
    this.stock,
    this.terms,
    this.validUntil,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String title;
  final String? description;
  final String category;
  final int costFet;
  final String deliveryType;
  final bool isActive;
  final String? partnerLogoUrl;
  final String? imageUrl;
  final String? originalValue;
  final int? stock;
  final String? terms;
  final DateTime? validUntil;

  bool get isLimitedStock => stock != null;

  factory MarketplaceOffer.fromRow(Map<String, dynamic> row) {
    final partner = Map<String, dynamic>.from(
      (row['partner'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return MarketplaceOffer(
      id: row['id']?.toString() ?? '',
      partnerId: row['partner_id']?.toString() ?? '',
      partnerName: partner['name']?.toString() ?? 'Partner',
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString(),
      category: row['category']?.toString() ?? 'reward',
      costFet: (row['cost_fet'] as num?)?.toInt() ?? 0,
      deliveryType: row['delivery_type']?.toString() ?? 'voucher',
      isActive: row['is_active'] as bool? ?? true,
      partnerLogoUrl: partner['logo_url']?.toString(),
      imageUrl: row['image_url']?.toString(),
      originalValue: row['original_value']?.toString(),
      stock: (row['stock'] as num?)?.toInt(),
      terms: row['terms']?.toString(),
      validUntil: row['valid_until'] != null
          ? DateTime.tryParse(row['valid_until'].toString())
          : null,
    );
  }
}

class MarketplaceRedemption {
  const MarketplaceRedemption({
    required this.id,
    required this.offerId,
    required this.title,
    required this.partnerName,
    required this.costFet,
    required this.deliveryType,
    required this.status,
    required this.redeemedAt,
    this.deliveryValue,
    this.expiresAt,
    this.imageUrl,
  });

  final String id;
  final String offerId;
  final String title;
  final String partnerName;
  final int costFet;
  final String deliveryType;
  final String status;
  final DateTime redeemedAt;
  final String? deliveryValue;
  final DateTime? expiresAt;
  final String? imageUrl;

  factory MarketplaceRedemption.fromRow(Map<String, dynamic> row) {
    final offer = Map<String, dynamic>.from(
      (row['offer'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final partner = Map<String, dynamic>.from(
      (offer['partner'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    return MarketplaceRedemption(
      id: row['id']?.toString() ?? '',
      offerId: row['offer_id']?.toString() ?? '',
      title: offer['title']?.toString() ?? 'Reward',
      partnerName: partner['name']?.toString() ?? 'Partner',
      costFet: (row['cost_fet'] as num?)?.toInt() ?? 0,
      deliveryType: row['delivery_type']?.toString() ?? 'voucher',
      status: row['status']?.toString() ?? 'pending',
      redeemedAt:
          DateTime.tryParse(row['redeemed_at']?.toString() ?? '') ??
          DateTime.now(),
      deliveryValue: row['delivery_value']?.toString(),
      expiresAt: row['expires_at'] != null
          ? DateTime.tryParse(row['expires_at'].toString())
          : null,
      imageUrl: offer['image_url']?.toString(),
    );
  }
}

class MarketplaceRedeemResult {
  const MarketplaceRedeemResult({
    required this.status,
    required this.redemptionId,
    required this.deliveryType,
    required this.balanceAfter,
    this.deliveryValue,
  });

  final String status;
  final String redemptionId;
  final String deliveryType;
  final int balanceAfter;
  final String? deliveryValue;

  factory MarketplaceRedeemResult.fromJson(Map<String, dynamic> json) {
    return MarketplaceRedeemResult(
      status: json['status']?.toString() ?? 'pending',
      redemptionId: json['redemption_id']?.toString() ?? '',
      deliveryType: json['delivery_type']?.toString() ?? 'voucher',
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      deliveryValue: json['delivery_value']?.toString(),
    );
  }
}
