import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_category_model.freezed.dart';
part 'menu_category_model.g.dart';

/// Maps to `public.menu_categories` table.
@freezed
class MenuCategoryModel with _$MenuCategoryModel {
  const factory MenuCategoryModel({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    required String name,
    @JsonKey(name: 'display_order') @Default(0) int displayOrder,
    @JsonKey(name: 'is_visible') @Default(true) bool isVisible,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _MenuCategoryModel;

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$MenuCategoryModelFromJson(json);
}
