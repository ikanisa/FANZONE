// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'venue_match_stake_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VenueMatchStakeModel _$VenueMatchStakeModelFromJson(Map<String, dynamic> json) {
  return _VenueMatchStakeModel.fromJson(json);
}

/// @nodoc
mixin _$VenueMatchStakeModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String get venueId => throw _privateConstructorUsedError;
  @JsonKey(name: 'match_id')
  String get matchId => throw _privateConstructorUsedError;
  @JsonKey(name: 'entry_fee_fet')
  int get entryFeeFet => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_pool_fet')
  int get totalPoolFet => throw _privateConstructorUsedError;
  VenueStakeStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this VenueMatchStakeModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VenueMatchStakeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VenueMatchStakeModelCopyWith<VenueMatchStakeModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VenueMatchStakeModelCopyWith<$Res> {
  factory $VenueMatchStakeModelCopyWith(
    VenueMatchStakeModel value,
    $Res Function(VenueMatchStakeModel) then,
  ) = _$VenueMatchStakeModelCopyWithImpl<$Res, VenueMatchStakeModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'match_id') String matchId,
    @JsonKey(name: 'entry_fee_fet') int entryFeeFet,
    @JsonKey(name: 'total_pool_fet') int totalPoolFet,
    VenueStakeStatus status,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class _$VenueMatchStakeModelCopyWithImpl<
  $Res,
  $Val extends VenueMatchStakeModel
>
    implements $VenueMatchStakeModelCopyWith<$Res> {
  _$VenueMatchStakeModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VenueMatchStakeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? matchId = null,
    Object? entryFeeFet = null,
    Object? totalPoolFet = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
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
            matchId: null == matchId
                ? _value.matchId
                : matchId // ignore: cast_nullable_to_non_nullable
                      as String,
            entryFeeFet: null == entryFeeFet
                ? _value.entryFeeFet
                : entryFeeFet // ignore: cast_nullable_to_non_nullable
                      as int,
            totalPoolFet: null == totalPoolFet
                ? _value.totalPoolFet
                : totalPoolFet // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as VenueStakeStatus,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VenueMatchStakeModelImplCopyWith<$Res>
    implements $VenueMatchStakeModelCopyWith<$Res> {
  factory _$$VenueMatchStakeModelImplCopyWith(
    _$VenueMatchStakeModelImpl value,
    $Res Function(_$VenueMatchStakeModelImpl) then,
  ) = __$$VenueMatchStakeModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'match_id') String matchId,
    @JsonKey(name: 'entry_fee_fet') int entryFeeFet,
    @JsonKey(name: 'total_pool_fet') int totalPoolFet,
    VenueStakeStatus status,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class __$$VenueMatchStakeModelImplCopyWithImpl<$Res>
    extends _$VenueMatchStakeModelCopyWithImpl<$Res, _$VenueMatchStakeModelImpl>
    implements _$$VenueMatchStakeModelImplCopyWith<$Res> {
  __$$VenueMatchStakeModelImplCopyWithImpl(
    _$VenueMatchStakeModelImpl _value,
    $Res Function(_$VenueMatchStakeModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VenueMatchStakeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? matchId = null,
    Object? entryFeeFet = null,
    Object? totalPoolFet = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$VenueMatchStakeModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        matchId: null == matchId
            ? _value.matchId
            : matchId // ignore: cast_nullable_to_non_nullable
                  as String,
        entryFeeFet: null == entryFeeFet
            ? _value.entryFeeFet
            : entryFeeFet // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPoolFet: null == totalPoolFet
            ? _value.totalPoolFet
            : totalPoolFet // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as VenueStakeStatus,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VenueMatchStakeModelImpl implements _VenueMatchStakeModel {
  const _$VenueMatchStakeModelImpl({
    required this.id,
    @JsonKey(name: 'venue_id') required this.venueId,
    @JsonKey(name: 'match_id') required this.matchId,
    @JsonKey(name: 'entry_fee_fet') required this.entryFeeFet,
    @JsonKey(name: 'total_pool_fet') required this.totalPoolFet,
    required this.status,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
  });

  factory _$VenueMatchStakeModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$VenueMatchStakeModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'venue_id')
  final String venueId;
  @override
  @JsonKey(name: 'match_id')
  final String matchId;
  @override
  @JsonKey(name: 'entry_fee_fet')
  final int entryFeeFet;
  @override
  @JsonKey(name: 'total_pool_fet')
  final int totalPoolFet;
  @override
  final VenueStakeStatus status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'VenueMatchStakeModel(id: $id, venueId: $venueId, matchId: $matchId, entryFeeFet: $entryFeeFet, totalPoolFet: $totalPoolFet, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VenueMatchStakeModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.matchId, matchId) || other.matchId == matchId) &&
            (identical(other.entryFeeFet, entryFeeFet) ||
                other.entryFeeFet == entryFeeFet) &&
            (identical(other.totalPoolFet, totalPoolFet) ||
                other.totalPoolFet == totalPoolFet) &&
            (identical(other.status, status) || other.status == status) &&
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
    matchId,
    entryFeeFet,
    totalPoolFet,
    status,
    createdAt,
    updatedAt,
  );

  /// Create a copy of VenueMatchStakeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VenueMatchStakeModelImplCopyWith<_$VenueMatchStakeModelImpl>
  get copyWith =>
      __$$VenueMatchStakeModelImplCopyWithImpl<_$VenueMatchStakeModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VenueMatchStakeModelImplToJson(this);
  }
}

abstract class _VenueMatchStakeModel implements VenueMatchStakeModel {
  const factory _VenueMatchStakeModel({
    required final String id,
    @JsonKey(name: 'venue_id') required final String venueId,
    @JsonKey(name: 'match_id') required final String matchId,
    @JsonKey(name: 'entry_fee_fet') required final int entryFeeFet,
    @JsonKey(name: 'total_pool_fet') required final int totalPoolFet,
    required final VenueStakeStatus status,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
  }) = _$VenueMatchStakeModelImpl;

  factory _VenueMatchStakeModel.fromJson(Map<String, dynamic> json) =
      _$VenueMatchStakeModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'venue_id')
  String get venueId;
  @override
  @JsonKey(name: 'match_id')
  String get matchId;
  @override
  @JsonKey(name: 'entry_fee_fet')
  int get entryFeeFet;
  @override
  @JsonKey(name: 'total_pool_fet')
  int get totalPoolFet;
  @override
  VenueStakeStatus get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of VenueMatchStakeModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VenueMatchStakeModelImplCopyWith<_$VenueMatchStakeModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
