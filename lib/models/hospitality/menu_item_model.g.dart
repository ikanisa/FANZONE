// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MenuItemModelImpl _$$MenuItemModelImplFromJson(
  Map<String, dynamic> json,
) => _$MenuItemModelImpl(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  categoryId: json['category_id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  price: (json['price'] as num).toDouble(),
  currencyCode: json['currency_code'] as String,
  imageUrl: json['image_url'] as String?,
  isAvailable: json['is_available'] as bool? ?? true,
  isFeatured: json['is_featured'] as bool? ?? false,
  dietaryFlags:
      json['dietary_flags'] as Map<String, dynamic>? ??
      const <String, dynamic>{},
  allergens:
      (json['allergens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  addOns:
      (json['add_ons'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const <Map<String, dynamic>>[],
  metadata:
      json['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$MenuItemModelImplToJson(_$MenuItemModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'venue_id': instance.venueId,
      'category_id': instance.categoryId,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'currency_code': instance.currencyCode,
      'image_url': instance.imageUrl,
      'is_available': instance.isAvailable,
      'is_featured': instance.isFeatured,
      'dietary_flags': instance.dietaryFlags,
      'allergens': instance.allergens,
      'add_ons': instance.addOns,
      'metadata': instance.metadata,
      'display_order': instance.displayOrder,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
