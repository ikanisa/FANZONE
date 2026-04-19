// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_supporter_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TeamSupporterModel _$TeamSupporterModelFromJson(Map<String, dynamic> json) {
  return _TeamSupporterModel.fromJson(json);
}

/// @nodoc
mixin _$TeamSupporterModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'anonymous_fan_id')
  String get anonymousFanId => throw _privateConstructorUsedError;
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;

  /// Serializes this TeamSupporterModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeamSupporterModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamSupporterModelCopyWith<TeamSupporterModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamSupporterModelCopyWith<$Res> {
  factory $TeamSupporterModelCopyWith(
    TeamSupporterModel value,
    $Res Function(TeamSupporterModel) then,
  ) = _$TeamSupporterModelCopyWithImpl<$Res, TeamSupporterModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'anonymous_fan_id') String anonymousFanId,
    @JsonKey(name: 'joined_at') DateTime joinedAt,
    @JsonKey(name: 'is_active') bool isActive,
  });
}

/// @nodoc
class _$TeamSupporterModelCopyWithImpl<$Res, $Val extends TeamSupporterModel>
    implements $TeamSupporterModelCopyWith<$Res> {
  _$TeamSupporterModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamSupporterModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? userId = null,
    Object? anonymousFanId = null,
    Object? joinedAt = null,
    Object? isActive = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            anonymousFanId: null == anonymousFanId
                ? _value.anonymousFanId
                : anonymousFanId // ignore: cast_nullable_to_non_nullable
                      as String,
            joinedAt: null == joinedAt
                ? _value.joinedAt
                : joinedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TeamSupporterModelImplCopyWith<$Res>
    implements $TeamSupporterModelCopyWith<$Res> {
  factory _$$TeamSupporterModelImplCopyWith(
    _$TeamSupporterModelImpl value,
    $Res Function(_$TeamSupporterModelImpl) then,
  ) = __$$TeamSupporterModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'anonymous_fan_id') String anonymousFanId,
    @JsonKey(name: 'joined_at') DateTime joinedAt,
    @JsonKey(name: 'is_active') bool isActive,
  });
}

/// @nodoc
class __$$TeamSupporterModelImplCopyWithImpl<$Res>
    extends _$TeamSupporterModelCopyWithImpl<$Res, _$TeamSupporterModelImpl>
    implements _$$TeamSupporterModelImplCopyWith<$Res> {
  __$$TeamSupporterModelImplCopyWithImpl(
    _$TeamSupporterModelImpl _value,
    $Res Function(_$TeamSupporterModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamSupporterModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? userId = null,
    Object? anonymousFanId = null,
    Object? joinedAt = null,
    Object? isActive = null,
  }) {
    return _then(
      _$TeamSupporterModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        anonymousFanId: null == anonymousFanId
            ? _value.anonymousFanId
            : anonymousFanId // ignore: cast_nullable_to_non_nullable
                  as String,
        joinedAt: null == joinedAt
            ? _value.joinedAt
            : joinedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TeamSupporterModelImpl implements _TeamSupporterModel {
  const _$TeamSupporterModelImpl({
    required this.id,
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'anonymous_fan_id') required this.anonymousFanId,
    @JsonKey(name: 'joined_at') required this.joinedAt,
    @JsonKey(name: 'is_active') this.isActive = true,
  });

  factory _$TeamSupporterModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeamSupporterModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'anonymous_fan_id')
  final String anonymousFanId;
  @override
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;

  @override
  String toString() {
    return 'TeamSupporterModel(id: $id, teamId: $teamId, userId: $userId, anonymousFanId: $anonymousFanId, joinedAt: $joinedAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamSupporterModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.anonymousFanId, anonymousFanId) ||
                other.anonymousFanId == anonymousFanId) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    teamId,
    userId,
    anonymousFanId,
    joinedAt,
    isActive,
  );

  /// Create a copy of TeamSupporterModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamSupporterModelImplCopyWith<_$TeamSupporterModelImpl> get copyWith =>
      __$$TeamSupporterModelImplCopyWithImpl<_$TeamSupporterModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TeamSupporterModelImplToJson(this);
  }
}

abstract class _TeamSupporterModel implements TeamSupporterModel {
  const factory _TeamSupporterModel({
    required final String id,
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'anonymous_fan_id') required final String anonymousFanId,
    @JsonKey(name: 'joined_at') required final DateTime joinedAt,
    @JsonKey(name: 'is_active') final bool isActive,
  }) = _$TeamSupporterModelImpl;

  factory _TeamSupporterModel.fromJson(Map<String, dynamic> json) =
      _$TeamSupporterModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'anonymous_fan_id')
  String get anonymousFanId;
  @override
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;

  /// Create a copy of TeamSupporterModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamSupporterModelImplCopyWith<_$TeamSupporterModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnonymousFanRecord _$AnonymousFanRecordFromJson(Map<String, dynamic> json) {
  return _AnonymousFanRecord.fromJson(json);
}

/// @nodoc
mixin _$AnonymousFanRecord {
  @JsonKey(name: 'anonymous_fan_id')
  String get anonymousFanId => throw _privateConstructorUsedError;
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt => throw _privateConstructorUsedError;

  /// Serializes this AnonymousFanRecord to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnonymousFanRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnonymousFanRecordCopyWith<AnonymousFanRecord> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnonymousFanRecordCopyWith<$Res> {
  factory $AnonymousFanRecordCopyWith(
    AnonymousFanRecord value,
    $Res Function(AnonymousFanRecord) then,
  ) = _$AnonymousFanRecordCopyWithImpl<$Res, AnonymousFanRecord>;
  @useResult
  $Res call({
    @JsonKey(name: 'anonymous_fan_id') String anonymousFanId,
    @JsonKey(name: 'joined_at') DateTime joinedAt,
  });
}

/// @nodoc
class _$AnonymousFanRecordCopyWithImpl<$Res, $Val extends AnonymousFanRecord>
    implements $AnonymousFanRecordCopyWith<$Res> {
  _$AnonymousFanRecordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnonymousFanRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? anonymousFanId = null, Object? joinedAt = null}) {
    return _then(
      _value.copyWith(
            anonymousFanId: null == anonymousFanId
                ? _value.anonymousFanId
                : anonymousFanId // ignore: cast_nullable_to_non_nullable
                      as String,
            joinedAt: null == joinedAt
                ? _value.joinedAt
                : joinedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnonymousFanRecordImplCopyWith<$Res>
    implements $AnonymousFanRecordCopyWith<$Res> {
  factory _$$AnonymousFanRecordImplCopyWith(
    _$AnonymousFanRecordImpl value,
    $Res Function(_$AnonymousFanRecordImpl) then,
  ) = __$$AnonymousFanRecordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'anonymous_fan_id') String anonymousFanId,
    @JsonKey(name: 'joined_at') DateTime joinedAt,
  });
}

/// @nodoc
class __$$AnonymousFanRecordImplCopyWithImpl<$Res>
    extends _$AnonymousFanRecordCopyWithImpl<$Res, _$AnonymousFanRecordImpl>
    implements _$$AnonymousFanRecordImplCopyWith<$Res> {
  __$$AnonymousFanRecordImplCopyWithImpl(
    _$AnonymousFanRecordImpl _value,
    $Res Function(_$AnonymousFanRecordImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnonymousFanRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? anonymousFanId = null, Object? joinedAt = null}) {
    return _then(
      _$AnonymousFanRecordImpl(
        anonymousFanId: null == anonymousFanId
            ? _value.anonymousFanId
            : anonymousFanId // ignore: cast_nullable_to_non_nullable
                  as String,
        joinedAt: null == joinedAt
            ? _value.joinedAt
            : joinedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnonymousFanRecordImpl implements _AnonymousFanRecord {
  const _$AnonymousFanRecordImpl({
    @JsonKey(name: 'anonymous_fan_id') required this.anonymousFanId,
    @JsonKey(name: 'joined_at') required this.joinedAt,
  });

  factory _$AnonymousFanRecordImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnonymousFanRecordImplFromJson(json);

  @override
  @JsonKey(name: 'anonymous_fan_id')
  final String anonymousFanId;
  @override
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;

  @override
  String toString() {
    return 'AnonymousFanRecord(anonymousFanId: $anonymousFanId, joinedAt: $joinedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnonymousFanRecordImpl &&
            (identical(other.anonymousFanId, anonymousFanId) ||
                other.anonymousFanId == anonymousFanId) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, anonymousFanId, joinedAt);

  /// Create a copy of AnonymousFanRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnonymousFanRecordImplCopyWith<_$AnonymousFanRecordImpl> get copyWith =>
      __$$AnonymousFanRecordImplCopyWithImpl<_$AnonymousFanRecordImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AnonymousFanRecordImplToJson(this);
  }
}

abstract class _AnonymousFanRecord implements AnonymousFanRecord {
  const factory _AnonymousFanRecord({
    @JsonKey(name: 'anonymous_fan_id') required final String anonymousFanId,
    @JsonKey(name: 'joined_at') required final DateTime joinedAt,
  }) = _$AnonymousFanRecordImpl;

  factory _AnonymousFanRecord.fromJson(Map<String, dynamic> json) =
      _$AnonymousFanRecordImpl.fromJson;

  @override
  @JsonKey(name: 'anonymous_fan_id')
  String get anonymousFanId;
  @override
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt;

  /// Create a copy of AnonymousFanRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnonymousFanRecordImplCopyWith<_$AnonymousFanRecordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
