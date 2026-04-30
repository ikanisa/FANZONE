// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'venue_table_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VenueTableModel _$VenueTableModelFromJson(Map<String, dynamic> json) {
  return _VenueTableModel.fromJson(json);
}

/// @nodoc
mixin _$VenueTableModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String get venueId => throw _privateConstructorUsedError;
  @JsonKey(name: 'table_number')
  String get tableNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'qr_code_url')
  String? get qrCodeUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'deep_link_uri')
  String? get deepLinkUri => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this VenueTableModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VenueTableModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VenueTableModelCopyWith<VenueTableModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VenueTableModelCopyWith<$Res> {
  factory $VenueTableModelCopyWith(
    VenueTableModel value,
    $Res Function(VenueTableModel) then,
  ) = _$VenueTableModelCopyWithImpl<$Res, VenueTableModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'table_number') String tableNumber,
    @JsonKey(name: 'qr_code_url') String? qrCodeUrl,
    @JsonKey(name: 'deep_link_uri') String? deepLinkUri,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class _$VenueTableModelCopyWithImpl<$Res, $Val extends VenueTableModel>
    implements $VenueTableModelCopyWith<$Res> {
  _$VenueTableModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VenueTableModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? tableNumber = null,
    Object? qrCodeUrl = freezed,
    Object? deepLinkUri = freezed,
    Object? isActive = null,
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
            tableNumber: null == tableNumber
                ? _value.tableNumber
                : tableNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            qrCodeUrl: freezed == qrCodeUrl
                ? _value.qrCodeUrl
                : qrCodeUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            deepLinkUri: freezed == deepLinkUri
                ? _value.deepLinkUri
                : deepLinkUri // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
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
abstract class _$$VenueTableModelImplCopyWith<$Res>
    implements $VenueTableModelCopyWith<$Res> {
  factory _$$VenueTableModelImplCopyWith(
    _$VenueTableModelImpl value,
    $Res Function(_$VenueTableModelImpl) then,
  ) = __$$VenueTableModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'table_number') String tableNumber,
    @JsonKey(name: 'qr_code_url') String? qrCodeUrl,
    @JsonKey(name: 'deep_link_uri') String? deepLinkUri,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class __$$VenueTableModelImplCopyWithImpl<$Res>
    extends _$VenueTableModelCopyWithImpl<$Res, _$VenueTableModelImpl>
    implements _$$VenueTableModelImplCopyWith<$Res> {
  __$$VenueTableModelImplCopyWithImpl(
    _$VenueTableModelImpl _value,
    $Res Function(_$VenueTableModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VenueTableModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? tableNumber = null,
    Object? qrCodeUrl = freezed,
    Object? deepLinkUri = freezed,
    Object? isActive = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$VenueTableModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        tableNumber: null == tableNumber
            ? _value.tableNumber
            : tableNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        qrCodeUrl: freezed == qrCodeUrl
            ? _value.qrCodeUrl
            : qrCodeUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        deepLinkUri: freezed == deepLinkUri
            ? _value.deepLinkUri
            : deepLinkUri // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
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
class _$VenueTableModelImpl extends _VenueTableModel {
  const _$VenueTableModelImpl({
    required this.id,
    @JsonKey(name: 'venue_id') required this.venueId,
    @JsonKey(name: 'table_number') required this.tableNumber,
    @JsonKey(name: 'qr_code_url') this.qrCodeUrl,
    @JsonKey(name: 'deep_link_uri') this.deepLinkUri,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  }) : super._();

  factory _$VenueTableModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$VenueTableModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'venue_id')
  final String venueId;
  @override
  @JsonKey(name: 'table_number')
  final String tableNumber;
  @override
  @JsonKey(name: 'qr_code_url')
  final String? qrCodeUrl;
  @override
  @JsonKey(name: 'deep_link_uri')
  final String? deepLinkUri;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'VenueTableModel(id: $id, venueId: $venueId, tableNumber: $tableNumber, qrCodeUrl: $qrCodeUrl, deepLinkUri: $deepLinkUri, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VenueTableModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.tableNumber, tableNumber) ||
                other.tableNumber == tableNumber) &&
            (identical(other.qrCodeUrl, qrCodeUrl) ||
                other.qrCodeUrl == qrCodeUrl) &&
            (identical(other.deepLinkUri, deepLinkUri) ||
                other.deepLinkUri == deepLinkUri) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
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
    tableNumber,
    qrCodeUrl,
    deepLinkUri,
    isActive,
    createdAt,
    updatedAt,
  );

  /// Create a copy of VenueTableModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VenueTableModelImplCopyWith<_$VenueTableModelImpl> get copyWith =>
      __$$VenueTableModelImplCopyWithImpl<_$VenueTableModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VenueTableModelImplToJson(this);
  }
}

abstract class _VenueTableModel extends VenueTableModel {
  const factory _VenueTableModel({
    required final String id,
    @JsonKey(name: 'venue_id') required final String venueId,
    @JsonKey(name: 'table_number') required final String tableNumber,
    @JsonKey(name: 'qr_code_url') final String? qrCodeUrl,
    @JsonKey(name: 'deep_link_uri') final String? deepLinkUri,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$VenueTableModelImpl;
  const _VenueTableModel._() : super._();

  factory _VenueTableModel.fromJson(Map<String, dynamic> json) =
      _$VenueTableModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'venue_id')
  String get venueId;
  @override
  @JsonKey(name: 'table_number')
  String get tableNumber;
  @override
  @JsonKey(name: 'qr_code_url')
  String? get qrCodeUrl;
  @override
  @JsonKey(name: 'deep_link_uri')
  String? get deepLinkUri;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of VenueTableModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VenueTableModelImplCopyWith<_$VenueTableModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
