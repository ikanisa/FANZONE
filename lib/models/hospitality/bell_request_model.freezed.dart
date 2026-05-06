// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bell_request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BellRequestModel _$BellRequestModelFromJson(Map<String, dynamic> json) {
  return _BellRequestModel.fromJson(json);
}

/// @nodoc
mixin _$BellRequestModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String get venueId => throw _privateConstructorUsedError;
  @JsonKey(name: 'table_id')
  String get tableId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  @JsonKey(name: 'acknowledged_at')
  DateTime? get acknowledgedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'acknowledged_by')
  String? get acknowledgedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this BellRequestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BellRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BellRequestModelCopyWith<BellRequestModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BellRequestModelCopyWith<$Res> {
  factory $BellRequestModelCopyWith(
    BellRequestModel value,
    $Res Function(BellRequestModel) then,
  ) = _$BellRequestModelCopyWithImpl<$Res, BellRequestModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'table_id') String tableId,
    @JsonKey(name: 'user_id') String userId,
    String? message,
    @JsonKey(name: 'acknowledged_at') DateTime? acknowledgedAt,
    @JsonKey(name: 'acknowledged_by') String? acknowledgedBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$BellRequestModelCopyWithImpl<$Res, $Val extends BellRequestModel>
    implements $BellRequestModelCopyWith<$Res> {
  _$BellRequestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BellRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? tableId = null,
    Object? userId = null,
    Object? message = freezed,
    Object? acknowledgedAt = freezed,
    Object? acknowledgedBy = freezed,
    Object? createdAt = freezed,
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
            tableId: null == tableId
                ? _value.tableId
                : tableId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            message: freezed == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String?,
            acknowledgedAt: freezed == acknowledgedAt
                ? _value.acknowledgedAt
                : acknowledgedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            acknowledgedBy: freezed == acknowledgedBy
                ? _value.acknowledgedBy
                : acknowledgedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BellRequestModelImplCopyWith<$Res>
    implements $BellRequestModelCopyWith<$Res> {
  factory _$$BellRequestModelImplCopyWith(
    _$BellRequestModelImpl value,
    $Res Function(_$BellRequestModelImpl) then,
  ) = __$$BellRequestModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'table_id') String tableId,
    @JsonKey(name: 'user_id') String userId,
    String? message,
    @JsonKey(name: 'acknowledged_at') DateTime? acknowledgedAt,
    @JsonKey(name: 'acknowledged_by') String? acknowledgedBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$BellRequestModelImplCopyWithImpl<$Res>
    extends _$BellRequestModelCopyWithImpl<$Res, _$BellRequestModelImpl>
    implements _$$BellRequestModelImplCopyWith<$Res> {
  __$$BellRequestModelImplCopyWithImpl(
    _$BellRequestModelImpl _value,
    $Res Function(_$BellRequestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BellRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? tableId = null,
    Object? userId = null,
    Object? message = freezed,
    Object? acknowledgedAt = freezed,
    Object? acknowledgedBy = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$BellRequestModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        tableId: null == tableId
            ? _value.tableId
            : tableId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        message: freezed == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String?,
        acknowledgedAt: freezed == acknowledgedAt
            ? _value.acknowledgedAt
            : acknowledgedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        acknowledgedBy: freezed == acknowledgedBy
            ? _value.acknowledgedBy
            : acknowledgedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BellRequestModelImpl extends _BellRequestModel {
  const _$BellRequestModelImpl({
    required this.id,
    @JsonKey(name: 'venue_id') required this.venueId,
    @JsonKey(name: 'table_id') required this.tableId,
    @JsonKey(name: 'user_id') required this.userId,
    this.message,
    @JsonKey(name: 'acknowledged_at') this.acknowledgedAt,
    @JsonKey(name: 'acknowledged_by') this.acknowledgedBy,
    @JsonKey(name: 'created_at') this.createdAt,
  }) : super._();

  factory _$BellRequestModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BellRequestModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'venue_id')
  final String venueId;
  @override
  @JsonKey(name: 'table_id')
  final String tableId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final String? message;
  @override
  @JsonKey(name: 'acknowledged_at')
  final DateTime? acknowledgedAt;
  @override
  @JsonKey(name: 'acknowledged_by')
  final String? acknowledgedBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'BellRequestModel(id: $id, venueId: $venueId, tableId: $tableId, userId: $userId, message: $message, acknowledgedAt: $acknowledgedAt, acknowledgedBy: $acknowledgedBy, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BellRequestModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.tableId, tableId) || other.tableId == tableId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.acknowledgedAt, acknowledgedAt) ||
                other.acknowledgedAt == acknowledgedAt) &&
            (identical(other.acknowledgedBy, acknowledgedBy) ||
                other.acknowledgedBy == acknowledgedBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    venueId,
    tableId,
    userId,
    message,
    acknowledgedAt,
    acknowledgedBy,
    createdAt,
  );

  /// Create a copy of BellRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BellRequestModelImplCopyWith<_$BellRequestModelImpl> get copyWith =>
      __$$BellRequestModelImplCopyWithImpl<_$BellRequestModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BellRequestModelImplToJson(this);
  }
}

abstract class _BellRequestModel extends BellRequestModel {
  const factory _BellRequestModel({
    required final String id,
    @JsonKey(name: 'venue_id') required final String venueId,
    @JsonKey(name: 'table_id') required final String tableId,
    @JsonKey(name: 'user_id') required final String userId,
    final String? message,
    @JsonKey(name: 'acknowledged_at') final DateTime? acknowledgedAt,
    @JsonKey(name: 'acknowledged_by') final String? acknowledgedBy,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$BellRequestModelImpl;
  const _BellRequestModel._() : super._();

  factory _BellRequestModel.fromJson(Map<String, dynamic> json) =
      _$BellRequestModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'venue_id')
  String get venueId;
  @override
  @JsonKey(name: 'table_id')
  String get tableId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String? get message;
  @override
  @JsonKey(name: 'acknowledged_at')
  DateTime? get acknowledgedAt;
  @override
  @JsonKey(name: 'acknowledged_by')
  String? get acknowledgedBy;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of BellRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BellRequestModelImplCopyWith<_$BellRequestModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
