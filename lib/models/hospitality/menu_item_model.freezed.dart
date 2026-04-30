// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MenuItemModel _$MenuItemModelFromJson(Map<String, dynamic> json) {
  return _MenuItemModel.fromJson(json);
}

/// @nodoc
mixin _$MenuItemModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String get venueId => throw _privateConstructorUsedError;
  @JsonKey(name: 'category_id')
  String get categoryId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_code')
  String get currencyCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_available')
  bool get isAvailable => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_featured')
  bool get isFeatured => throw _privateConstructorUsedError;
  @JsonKey(name: 'dietary_flags')
  Map<String, dynamic> get dietaryFlags => throw _privateConstructorUsedError;
  List<String> get allergens => throw _privateConstructorUsedError;
  @JsonKey(name: 'add_ons')
  List<Map<String, dynamic>> get addOns => throw _privateConstructorUsedError;
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_order')
  int get displayOrder => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this MenuItemModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MenuItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MenuItemModelCopyWith<MenuItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MenuItemModelCopyWith<$Res> {
  factory $MenuItemModelCopyWith(
    MenuItemModel value,
    $Res Function(MenuItemModel) then,
  ) = _$MenuItemModelCopyWithImpl<$Res, MenuItemModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'category_id') String categoryId,
    String name,
    String? description,
    double price,
    @JsonKey(name: 'currency_code') String currencyCode,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'is_available') bool isAvailable,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'dietary_flags') Map<String, dynamic> dietaryFlags,
    List<String> allergens,
    @JsonKey(name: 'add_ons') List<Map<String, dynamic>> addOns,
    Map<String, dynamic> metadata,
    @JsonKey(name: 'display_order') int displayOrder,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class _$MenuItemModelCopyWithImpl<$Res, $Val extends MenuItemModel>
    implements $MenuItemModelCopyWith<$Res> {
  _$MenuItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MenuItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? categoryId = null,
    Object? name = null,
    Object? description = freezed,
    Object? price = null,
    Object? currencyCode = null,
    Object? imageUrl = freezed,
    Object? isAvailable = null,
    Object? isFeatured = null,
    Object? dietaryFlags = null,
    Object? allergens = null,
    Object? addOns = null,
    Object? metadata = null,
    Object? displayOrder = null,
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
            categoryId: null == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as double,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isAvailable: null == isAvailable
                ? _value.isAvailable
                : isAvailable // ignore: cast_nullable_to_non_nullable
                      as bool,
            isFeatured: null == isFeatured
                ? _value.isFeatured
                : isFeatured // ignore: cast_nullable_to_non_nullable
                      as bool,
            dietaryFlags: null == dietaryFlags
                ? _value.dietaryFlags
                : dietaryFlags // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            allergens: null == allergens
                ? _value.allergens
                : allergens // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            addOns: null == addOns
                ? _value.addOns
                : addOns // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>,
            metadata: null == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            displayOrder: null == displayOrder
                ? _value.displayOrder
                : displayOrder // ignore: cast_nullable_to_non_nullable
                      as int,
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
abstract class _$$MenuItemModelImplCopyWith<$Res>
    implements $MenuItemModelCopyWith<$Res> {
  factory _$$MenuItemModelImplCopyWith(
    _$MenuItemModelImpl value,
    $Res Function(_$MenuItemModelImpl) then,
  ) = __$$MenuItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'category_id') String categoryId,
    String name,
    String? description,
    double price,
    @JsonKey(name: 'currency_code') String currencyCode,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'is_available') bool isAvailable,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'dietary_flags') Map<String, dynamic> dietaryFlags,
    List<String> allergens,
    @JsonKey(name: 'add_ons') List<Map<String, dynamic>> addOns,
    Map<String, dynamic> metadata,
    @JsonKey(name: 'display_order') int displayOrder,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class __$$MenuItemModelImplCopyWithImpl<$Res>
    extends _$MenuItemModelCopyWithImpl<$Res, _$MenuItemModelImpl>
    implements _$$MenuItemModelImplCopyWith<$Res> {
  __$$MenuItemModelImplCopyWithImpl(
    _$MenuItemModelImpl _value,
    $Res Function(_$MenuItemModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MenuItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? categoryId = null,
    Object? name = null,
    Object? description = freezed,
    Object? price = null,
    Object? currencyCode = null,
    Object? imageUrl = freezed,
    Object? isAvailable = null,
    Object? isFeatured = null,
    Object? dietaryFlags = null,
    Object? allergens = null,
    Object? addOns = null,
    Object? metadata = null,
    Object? displayOrder = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$MenuItemModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryId: null == categoryId
            ? _value.categoryId
            : categoryId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as double,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isAvailable: null == isAvailable
            ? _value.isAvailable
            : isAvailable // ignore: cast_nullable_to_non_nullable
                  as bool,
        isFeatured: null == isFeatured
            ? _value.isFeatured
            : isFeatured // ignore: cast_nullable_to_non_nullable
                  as bool,
        dietaryFlags: null == dietaryFlags
            ? _value._dietaryFlags
            : dietaryFlags // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        allergens: null == allergens
            ? _value._allergens
            : allergens // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        addOns: null == addOns
            ? _value._addOns
            : addOns // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>,
        metadata: null == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        displayOrder: null == displayOrder
            ? _value.displayOrder
            : displayOrder // ignore: cast_nullable_to_non_nullable
                  as int,
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
class _$MenuItemModelImpl extends _MenuItemModel {
  const _$MenuItemModelImpl({
    required this.id,
    @JsonKey(name: 'venue_id') required this.venueId,
    @JsonKey(name: 'category_id') required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    @JsonKey(name: 'currency_code') required this.currencyCode,
    @JsonKey(name: 'image_url') this.imageUrl,
    @JsonKey(name: 'is_available') this.isAvailable = true,
    @JsonKey(name: 'is_featured') this.isFeatured = false,
    @JsonKey(name: 'dietary_flags')
    final Map<String, dynamic> dietaryFlags = const <String, dynamic>{},
    final List<String> allergens = const <String>[],
    @JsonKey(name: 'add_ons')
    final List<Map<String, dynamic>> addOns = const <Map<String, dynamic>>[],
    final Map<String, dynamic> metadata = const <String, dynamic>{},
    @JsonKey(name: 'display_order') this.displayOrder = 0,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  }) : _dietaryFlags = dietaryFlags,
       _allergens = allergens,
       _addOns = addOns,
       _metadata = metadata,
       super._();

  factory _$MenuItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$MenuItemModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'venue_id')
  final String venueId;
  @override
  @JsonKey(name: 'category_id')
  final String categoryId;
  @override
  final String name;
  @override
  final String? description;
  @override
  final double price;
  @override
  @JsonKey(name: 'currency_code')
  final String currencyCode;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey(name: 'is_available')
  final bool isAvailable;
  @override
  @JsonKey(name: 'is_featured')
  final bool isFeatured;
  final Map<String, dynamic> _dietaryFlags;
  @override
  @JsonKey(name: 'dietary_flags')
  Map<String, dynamic> get dietaryFlags {
    if (_dietaryFlags is EqualUnmodifiableMapView) return _dietaryFlags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dietaryFlags);
  }

  final List<String> _allergens;
  @override
  @JsonKey()
  List<String> get allergens {
    if (_allergens is EqualUnmodifiableListView) return _allergens;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergens);
  }

  final List<Map<String, dynamic>> _addOns;
  @override
  @JsonKey(name: 'add_ons')
  List<Map<String, dynamic>> get addOns {
    if (_addOns is EqualUnmodifiableListView) return _addOns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_addOns);
  }

  final Map<String, dynamic> _metadata;
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  @JsonKey(name: 'display_order')
  final int displayOrder;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'MenuItemModel(id: $id, venueId: $venueId, categoryId: $categoryId, name: $name, description: $description, price: $price, currencyCode: $currencyCode, imageUrl: $imageUrl, isAvailable: $isAvailable, isFeatured: $isFeatured, dietaryFlags: $dietaryFlags, allergens: $allergens, addOns: $addOns, metadata: $metadata, displayOrder: $displayOrder, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MenuItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            const DeepCollectionEquality().equals(
              other._dietaryFlags,
              _dietaryFlags,
            ) &&
            const DeepCollectionEquality().equals(
              other._allergens,
              _allergens,
            ) &&
            const DeepCollectionEquality().equals(other._addOns, _addOns) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder) &&
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
    categoryId,
    name,
    description,
    price,
    currencyCode,
    imageUrl,
    isAvailable,
    isFeatured,
    const DeepCollectionEquality().hash(_dietaryFlags),
    const DeepCollectionEquality().hash(_allergens),
    const DeepCollectionEquality().hash(_addOns),
    const DeepCollectionEquality().hash(_metadata),
    displayOrder,
    createdAt,
    updatedAt,
  );

  /// Create a copy of MenuItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MenuItemModelImplCopyWith<_$MenuItemModelImpl> get copyWith =>
      __$$MenuItemModelImplCopyWithImpl<_$MenuItemModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MenuItemModelImplToJson(this);
  }
}

abstract class _MenuItemModel extends MenuItemModel {
  const factory _MenuItemModel({
    required final String id,
    @JsonKey(name: 'venue_id') required final String venueId,
    @JsonKey(name: 'category_id') required final String categoryId,
    required final String name,
    final String? description,
    required final double price,
    @JsonKey(name: 'currency_code') required final String currencyCode,
    @JsonKey(name: 'image_url') final String? imageUrl,
    @JsonKey(name: 'is_available') final bool isAvailable,
    @JsonKey(name: 'is_featured') final bool isFeatured,
    @JsonKey(name: 'dietary_flags') final Map<String, dynamic> dietaryFlags,
    final List<String> allergens,
    @JsonKey(name: 'add_ons') final List<Map<String, dynamic>> addOns,
    final Map<String, dynamic> metadata,
    @JsonKey(name: 'display_order') final int displayOrder,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$MenuItemModelImpl;
  const _MenuItemModel._() : super._();

  factory _MenuItemModel.fromJson(Map<String, dynamic> json) =
      _$MenuItemModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'venue_id')
  String get venueId;
  @override
  @JsonKey(name: 'category_id')
  String get categoryId;
  @override
  String get name;
  @override
  String? get description;
  @override
  double get price;
  @override
  @JsonKey(name: 'currency_code')
  String get currencyCode;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  @JsonKey(name: 'is_available')
  bool get isAvailable;
  @override
  @JsonKey(name: 'is_featured')
  bool get isFeatured;
  @override
  @JsonKey(name: 'dietary_flags')
  Map<String, dynamic> get dietaryFlags;
  @override
  List<String> get allergens;
  @override
  @JsonKey(name: 'add_ons')
  List<Map<String, dynamic>> get addOns;
  @override
  Map<String, dynamic> get metadata;
  @override
  @JsonKey(name: 'display_order')
  int get displayOrder;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of MenuItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MenuItemModelImplCopyWith<_$MenuItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
