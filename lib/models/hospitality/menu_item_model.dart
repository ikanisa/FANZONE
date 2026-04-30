import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_item_model.freezed.dart';
part 'menu_item_model.g.dart';

/// Maps to `public.menu_items` table.
@freezed
class MenuItemModel with _$MenuItemModel {
  const factory MenuItemModel({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    @JsonKey(name: 'category_id') required String categoryId,
    required String name,
    String? description,
    required double price,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'is_available') @Default(true) bool isAvailable,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
    @JsonKey(name: 'dietary_flags')
    @Default(<String, dynamic>{})
    Map<String, dynamic> dietaryFlags,
    @Default(<String>[]) List<String> allergens,
    @JsonKey(name: 'add_ons')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> addOns,
    @Default(<String, dynamic>{}) Map<String, dynamic> metadata,
    @JsonKey(name: 'display_order') @Default(0) int displayOrder,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _MenuItemModel;

  const MenuItemModel._();

  factory MenuItemModel.fromJson(Map<String, dynamic> json) =>
      _$MenuItemModelFromJson(json);

  /// Formatted price for display (e.g., "€12.50" or "RWF 3,500").
  String get priceDisplay {
    if (currencyCode == 'EUR') {
      return '€${price.toStringAsFixed(2)}';
    } else if (currencyCode == 'RWF') {
      return 'RWF ${price.toStringAsFixed(0)}';
    }
    return '$currencyCode ${price.toStringAsFixed(2)}';
  }

  /// Whether this item is vegetarian.
  bool get isVegetarian =>
      dietaryFlags['vegetarian'] == true || dietaryFlags['vegan'] == true;

  /// Whether this item is vegan.
  bool get isVegan => dietaryFlags['vegan'] == true;

  /// Whether this item is gluten-free.
  bool get isGlutenFree => dietaryFlags['gluten_free'] == true;

  /// Whether this item has any add-on options.
  bool get hasAddOns => addOns.isNotEmpty;
}
