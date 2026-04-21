class PredictionMarketCatalogItem {
  const PredictionMarketCatalogItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.exampleSelection,
    required this.betType,
    required this.baseFet,
    required this.scope,
    required this.settlementType,
    required this.displayOrder,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final String description;
  final String exampleSelection;
  final String betType;
  final int baseFet;
  final String scope;
  final String settlementType;
  final int displayOrder;

  factory PredictionMarketCatalogItem.fromJson(Map<String, dynamic> json) {
    return PredictionMarketCatalogItem(
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      exampleSelection: json['example_selection']?.toString() ?? '',
      betType: json['bet_type']?.toString() ?? '',
      baseFet: (json['base_fet'] as num?)?.toInt() ?? 0,
      scope: json['scope']?.toString() ?? '',
      settlementType: json['settlement_type']?.toString() ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isMatchResult => id == 'match_result';

  bool get isBothTeamsToScore => id == 'btts';

  bool get isOverUnder25 => id == 'over_under_2_5';
}
