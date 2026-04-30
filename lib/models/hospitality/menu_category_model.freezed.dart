// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_category_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MenuCategoryModel _$MenuCategoryModelFromJson(Map<String, dynamic> json) {
  return _MenuCategoryModel.fromJson(json);
}

/// @nodoc
mixin _$MenuCategoryModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String get venueId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_order')
  int get displayOrder => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_visible')
  bool get isVisible => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this MenuCategoryModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MenuCategoryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MenuCategoryModelCopyWith<MenuCategoryModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MenuCategoryModelCopyWith<$Res> {
  factory $MenuCategoryModelCopyWith(
    MenuCategoryModel value,
    $Res Function(MenuCategoryModel) then,
  ) = _$MenuCategoryModelCopyWithImpl<$Res, MenuCategoryModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    String name,
    @JsonKey(name: 'display_order') int displayOrder,
    @JsonKey(name: 'is_visible') bool isVisible,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class _$MenuCategoryModelCopyWithImpl<$Res, $Val extends MenuCategoryModel>
    implements $MenuCategoryModelCopyWith<$Res> {
  _$MenuCategoryModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MenuCategoryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? name = null,
    Object? displayOrder = null,
    Object? isVisible = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            venueId: null == venueId
                ? _value.venueId
                : venueId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            displayOrder: null == displayOrder
                ? _value.displayOrder
                : displayOrder // ignore: cast_nullable_to_non_nullable
                      as int,
            isVisible: null == isVisible
                ? _value.isVisible
                : isVisible // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MenuCategoryModelImplCopyWith<$Res>
    implements $MenuCategoryModelCopyWith<$Res> {
  factory _$$MenuCategoryModelImplCopyWith(
    _$MenuCategoryModelImpl value,
    $Res Function(_$MenuCategoryModelImpl) then,
  ) = __$$MenuCategoryModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    String name,
    @JsonKey(name: 'display_order') int displayOrder,
    @JsonKey(name: 'is_visible') bool isVisible,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class __$$MenuCategoryModelImplCopyWithImpl<$Res>
    extends _$MenuCategoryModelCopyWithImpl<$Res, _$MenuCategoryModelImpl>
    implements _$$MenuCategoryModelImplCopyWith<$Res> {
  __$$MenuCategoryModelImplCopyWithImpl(
    _$MenuCategoryModelImpl _value,
    $Res Function(_$MenuCategoryModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MenuCategoryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? name = null,
    Object? displayOrder = null,
    Object? isVisible = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$MenuCategoryModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        displayOrder: null == displayOrder
            ? _value.displayOrder
            : displayOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        isVisible: null == isVisible
            ? _value.isVisible
            : isVisible // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MenuCategoryModelImpl implements _MenuCategoryModel {
  const _$MenuCategoryModelImpl({
    required this.id,
    @JsonKey(name: 'venue_id') required this.venueId,
    required this.name,
    @JsonKey(name: 'display_order') this.displayOrder = 0,
    @JsonKey(name: 'is_visible') this.isVisible = true,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  });

  factory _$MenuCategoryModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$MenuCategoryModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'venue_id')
  final String venueId;
  @override
  final String name;
  @override
  @JsonKey(name: 'display_order')
  final int displayOrder;
  @override
  @JsonKey(name: 'is_visible')
  final bool isVisible;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'MenuCategoryModel(id: $id, venueId: $venueId, name: $name, displayOrder: $displayOrder, isVisible: $isVisible, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MenuCategoryModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder) &&
            (identical(other.isVisible, isVisible) ||
                other.isVisible == isVisible) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    venueId,
    name,
    displayOrder,
    isVisible,
    createdAt,
    updatedAt,
  );

  /// Create a copy of MenuCategoryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MenuCategoryModelImplCopyWith<_$MenuCategoryModelImpl> get copyWith =>
      __$$MenuCategoryModelImplCopyWithImpl<_$MenuCategoryModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MenuCategoryModelImplToJson(this);
  }
}

abstract class _MenuCategoryModel implements MenuCategoryModel {
  const factory _MenuCategoryModel({
    required final String id,
    @JsonKey(name: 'venue_id') required final String venueId,
    required final String name,
    @JsonKey(name: 'display_order') final int displayOrder,
    @JsonKey(name: 'is_visible') final bool isVisible,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$MenuCategoryModelImpl;

  factory _MenuCategoryModel.fromJson(Map<String, dynamic> json) =
      _$MenuCategoryModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'venue_id')
  String get venueId;
  @override
  String get name;
  @override
  @JsonKey(name: 'display_order')
  int get displayOrder;
  @override
  @JsonKey(name: 'is_visible')
  bool get isVisible;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of MenuCategoryModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MenuCategoryModelImplCopyWith<_$MenuCategoryModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
