// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MenuCategoryModelImpl _$$MenuCategoryModelImplFromJson(
  Map<String, dynamic> json,
) => _$MenuCategoryModelImpl(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  name: json['name'] as String,
  displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
  isVisible: json['is_visible'] as bool? ?? true,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$MenuCategoryModelImplToJson(
  _$MenuCategoryModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'venue_id': instance.venueId,
  'name': instance.name,
  'display_order': instance.displayOrder,
  'is_visible': instance.isVisible,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
