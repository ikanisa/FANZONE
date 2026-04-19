// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pool.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ScorePool _$ScorePoolFromJson(Map<String, dynamic> json) {
  return _ScorePool.fromJson(json);
}

/// @nodoc
mixin _$ScorePool {
  String get id => throw _privateConstructorUsedError;
  String get matchId => throw _privateConstructorUsedError;
  String get matchName => throw _privateConstructorUsedError;
  String get creatorId => throw _privateConstructorUsedError;
  String get creatorName => throw _privateConstructorUsedError;
  String get creatorPrediction => throw _privateConstructorUsedError;
  int get stake => throw _privateConstructorUsedError;
  int get totalPool => throw _privateConstructorUsedError;
  int get participantsCount => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // 'open' | 'locked' | 'settled' | 'void'
  DateTime get lockAt => throw _privateConstructorUsedError;

  /// Serializes this ScorePool to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScorePool
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScorePoolCopyWith<ScorePool> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScorePoolCopyWith<$Res> {
  factory $ScorePoolCopyWith(ScorePool value, $Res Function(ScorePool) then) =
      _$ScorePoolCopyWithImpl<$Res, ScorePool>;
  @useResult
  $Res call({
    String id,
    String matchId,
    String matchName,
    String creatorId,
    String creatorName,
    String creatorPrediction,
    int stake,
    int totalPool,
    int participantsCount,
    String status,
    DateTime lockAt,
  });
}

/// @nodoc
class _$ScorePoolCopyWithImpl<$Res, $Val extends ScorePool>
    implements $ScorePoolCopyWith<$Res> {
  _$ScorePoolCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScorePool
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? matchId = null,
    Object? matchName = null,
    Object? creatorId = null,
    Object? creatorName = null,
    Object? creatorPrediction = null,
    Object? stake = null,
    Object? totalPool = null,
    Object? participantsCount = null,
    Object? status = null,
    Object? lockAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            matchId: null == matchId
                ? _value.matchId
                : matchId // ignore: cast_nullable_to_non_nullable
                      as String,
            matchName: null == matchName
                ? _value.matchName
                : matchName // ignore: cast_nullable_to_non_nullable
                      as String,
            creatorId: null == creatorId
                ? _value.creatorId
                : creatorId // ignore: cast_nullable_to_non_nullable
                      as String,
            creatorName: null == creatorName
                ? _value.creatorName
                : creatorName // ignore: cast_nullable_to_non_nullable
                      as String,
            creatorPrediction: null == creatorPrediction
                ? _value.creatorPrediction
                : creatorPrediction // ignore: cast_nullable_to_non_nullable
                      as String,
            stake: null == stake
                ? _value.stake
                : stake // ignore: cast_nullable_to_non_nullable
                      as int,
            totalPool: null == totalPool
                ? _value.totalPool
                : totalPool // ignore: cast_nullable_to_non_nullable
                      as int,
            participantsCount: null == participantsCount
                ? _value.participantsCount
                : participantsCount // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            lockAt: null == lockAt
                ? _value.lockAt
                : lockAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ScorePoolImplCopyWith<$Res>
    implements $ScorePoolCopyWith<$Res> {
  factory _$$ScorePoolImplCopyWith(
    _$ScorePoolImpl value,
    $Res Function(_$ScorePoolImpl) then,
  ) = __$$ScorePoolImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String matchId,
    String matchName,
    String creatorId,
    String creatorName,
    String creatorPrediction,
    int stake,
    int totalPool,
    int participantsCount,
    String status,
    DateTime lockAt,
  });
}

/// @nodoc
class __$$ScorePoolImplCopyWithImpl<$Res>
    extends _$ScorePoolCopyWithImpl<$Res, _$ScorePoolImpl>
    implements _$$ScorePoolImplCopyWith<$Res> {
  __$$ScorePoolImplCopyWithImpl(
    _$ScorePoolImpl _value,
    $Res Function(_$ScorePoolImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScorePool
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? matchId = null,
    Object? matchName = null,
    Object? creatorId = null,
    Object? creatorName = null,
    Object? creatorPrediction = null,
    Object? stake = null,
    Object? totalPool = null,
    Object? participantsCount = null,
    Object? status = null,
    Object? lockAt = null,
  }) {
    return _then(
      _$ScorePoolImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        matchId: null == matchId
            ? _value.matchId
            : matchId // ignore: cast_nullable_to_non_nullable
                  as String,
        matchName: null == matchName
            ? _value.matchName
            : matchName // ignore: cast_nullable_to_non_nullable
                  as String,
        creatorId: null == creatorId
            ? _value.creatorId
            : creatorId // ignore: cast_nullable_to_non_nullable
                  as String,
        creatorName: null == creatorName
            ? _value.creatorName
            : creatorName // ignore: cast_nullable_to_non_nullable
                  as String,
        creatorPrediction: null == creatorPrediction
            ? _value.creatorPrediction
            : creatorPrediction // ignore: cast_nullable_to_non_nullable
                  as String,
        stake: null == stake
            ? _value.stake
            : stake // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPool: null == totalPool
            ? _value.totalPool
            : totalPool // ignore: cast_nullable_to_non_nullable
                  as int,
        participantsCount: null == participantsCount
            ? _value.participantsCount
            : participantsCount // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        lockAt: null == lockAt
            ? _value.lockAt
            : lockAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ScorePoolImpl implements _ScorePool {
  const _$ScorePoolImpl({
    required this.id,
    required this.matchId,
    required this.matchName,
    required this.creatorId,
    required this.creatorName,
    required this.creatorPrediction,
    required this.stake,
    required this.totalPool,
    required this.participantsCount,
    required this.status,
    required this.lockAt,
  });

  factory _$ScorePoolImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScorePoolImplFromJson(json);

  @override
  final String id;
  @override
  final String matchId;
  @override
  final String matchName;
  @override
  final String creatorId;
  @override
  final String creatorName;
  @override
  final String creatorPrediction;
  @override
  final int stake;
  @override
  final int totalPool;
  @override
  final int participantsCount;
  @override
  final String status;
  // 'open' | 'locked' | 'settled' | 'void'
  @override
  final DateTime lockAt;

  @override
  String toString() {
    return 'ScorePool(id: $id, matchId: $matchId, matchName: $matchName, creatorId: $creatorId, creatorName: $creatorName, creatorPrediction: $creatorPrediction, stake: $stake, totalPool: $totalPool, participantsCount: $participantsCount, status: $status, lockAt: $lockAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScorePoolImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.matchId, matchId) || other.matchId == matchId) &&
            (identical(other.matchName, matchName) ||
                other.matchName == matchName) &&
            (identical(other.creatorId, creatorId) ||
                other.creatorId == creatorId) &&
            (identical(other.creatorName, creatorName) ||
                other.creatorName == creatorName) &&
            (identical(other.creatorPrediction, creatorPrediction) ||
                other.creatorPrediction == creatorPrediction) &&
            (identical(other.stake, stake) || other.stake == stake) &&
            (identical(other.totalPool, totalPool) ||
                other.totalPool == totalPool) &&
            (identical(other.participantsCount, participantsCount) ||
                other.participantsCount == participantsCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lockAt, lockAt) || other.lockAt == lockAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    matchId,
    matchName,
    creatorId,
    creatorName,
    creatorPrediction,
    stake,
    totalPool,
    participantsCount,
    status,
    lockAt,
  );

  /// Create a copy of ScorePool
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScorePoolImplCopyWith<_$ScorePoolImpl> get copyWith =>
      __$$ScorePoolImplCopyWithImpl<_$ScorePoolImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScorePoolImplToJson(this);
  }
}

abstract class _ScorePool implements ScorePool {
  const factory _ScorePool({
    required final String id,
    required final String matchId,
    required final String matchName,
    required final String creatorId,
    required final String creatorName,
    required final String creatorPrediction,
    required final int stake,
    required final int totalPool,
    required final int participantsCount,
    required final String status,
    required final DateTime lockAt,
  }) = _$ScorePoolImpl;

  factory _ScorePool.fromJson(Map<String, dynamic> json) =
      _$ScorePoolImpl.fromJson;

  @override
  String get id;
  @override
  String get matchId;
  @override
  String get matchName;
  @override
  String get creatorId;
  @override
  String get creatorName;
  @override
  String get creatorPrediction;
  @override
  int get stake;
  @override
  int get totalPool;
  @override
  int get participantsCount;
  @override
  String get status; // 'open' | 'locked' | 'settled' | 'void'
  @override
  DateTime get lockAt;

  /// Create a copy of ScorePool
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScorePoolImplCopyWith<_$ScorePoolImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PoolEntry _$PoolEntryFromJson(Map<String, dynamic> json) {
  return _PoolEntry.fromJson(json);
}

/// @nodoc
mixin _$PoolEntry {
  String get id => throw _privateConstructorUsedError;
  String get poolId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get userName => throw _privateConstructorUsedError;
  int get predictedHomeScore => throw _privateConstructorUsedError;
  int get predictedAwayScore => throw _privateConstructorUsedError;
  int get stake => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // 'active' | 'winner' | 'loser' | 'refunded'
  int get payout => throw _privateConstructorUsedError;

  /// Serializes this PoolEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PoolEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PoolEntryCopyWith<PoolEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PoolEntryCopyWith<$Res> {
  factory $PoolEntryCopyWith(PoolEntry value, $Res Function(PoolEntry) then) =
      _$PoolEntryCopyWithImpl<$Res, PoolEntry>;
  @useResult
  $Res call({
    String id,
    String poolId,
    String userId,
    String userName,
    int predictedHomeScore,
    int predictedAwayScore,
    int stake,
    String status,
    int payout,
  });
}

/// @nodoc
class _$PoolEntryCopyWithImpl<$Res, $Val extends PoolEntry>
    implements $PoolEntryCopyWith<$Res> {
  _$PoolEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PoolEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? poolId = null,
    Object? userId = null,
    Object? userName = null,
    Object? predictedHomeScore = null,
    Object? predictedAwayScore = null,
    Object? stake = null,
    Object? status = null,
    Object? payout = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            poolId: null == poolId
                ? _value.poolId
                : poolId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            userName: null == userName
                ? _value.userName
                : userName // ignore: cast_nullable_to_non_nullable
                      as String,
            predictedHomeScore: null == predictedHomeScore
                ? _value.predictedHomeScore
                : predictedHomeScore // ignore: cast_nullable_to_non_nullable
                      as int,
            predictedAwayScore: null == predictedAwayScore
                ? _value.predictedAwayScore
                : predictedAwayScore // ignore: cast_nullable_to_non_nullable
                      as int,
            stake: null == stake
                ? _value.stake
                : stake // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            payout: null == payout
                ? _value.payout
                : payout // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PoolEntryImplCopyWith<$Res>
    implements $PoolEntryCopyWith<$Res> {
  factory _$$PoolEntryImplCopyWith(
    _$PoolEntryImpl value,
    $Res Function(_$PoolEntryImpl) then,
  ) = __$$PoolEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String poolId,
    String userId,
    String userName,
    int predictedHomeScore,
    int predictedAwayScore,
    int stake,
    String status,
    int payout,
  });
}

/// @nodoc
class __$$PoolEntryImplCopyWithImpl<$Res>
    extends _$PoolEntryCopyWithImpl<$Res, _$PoolEntryImpl>
    implements _$$PoolEntryImplCopyWith<$Res> {
  __$$PoolEntryImplCopyWithImpl(
    _$PoolEntryImpl _value,
    $Res Function(_$PoolEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PoolEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? poolId = null,
    Object? userId = null,
    Object? userName = null,
    Object? predictedHomeScore = null,
    Object? predictedAwayScore = null,
    Object? stake = null,
    Object? status = null,
    Object? payout = null,
  }) {
    return _then(
      _$PoolEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        poolId: null == poolId
            ? _value.poolId
            : poolId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        userName: null == userName
            ? _value.userName
            : userName // ignore: cast_nullable_to_non_nullable
                  as String,
        predictedHomeScore: null == predictedHomeScore
            ? _value.predictedHomeScore
            : predictedHomeScore // ignore: cast_nullable_to_non_nullable
                  as int,
        predictedAwayScore: null == predictedAwayScore
            ? _value.predictedAwayScore
            : predictedAwayScore // ignore: cast_nullable_to_non_nullable
                  as int,
        stake: null == stake
            ? _value.stake
            : stake // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        payout: null == payout
            ? _value.payout
            : payout // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PoolEntryImpl implements _PoolEntry {
  const _$PoolEntryImpl({
    required this.id,
    required this.poolId,
    required this.userId,
    required this.userName,
    required this.predictedHomeScore,
    required this.predictedAwayScore,
    required this.stake,
    required this.status,
    required this.payout,
  });

  factory _$PoolEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$PoolEntryImplFromJson(json);

  @override
  final String id;
  @override
  final String poolId;
  @override
  final String userId;
  @override
  final String userName;
  @override
  final int predictedHomeScore;
  @override
  final int predictedAwayScore;
  @override
  final int stake;
  @override
  final String status;
  // 'active' | 'winner' | 'loser' | 'refunded'
  @override
  final int payout;

  @override
  String toString() {
    return 'PoolEntry(id: $id, poolId: $poolId, userId: $userId, userName: $userName, predictedHomeScore: $predictedHomeScore, predictedAwayScore: $predictedAwayScore, stake: $stake, status: $status, payout: $payout)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PoolEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.poolId, poolId) || other.poolId == poolId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.predictedHomeScore, predictedHomeScore) ||
                other.predictedHomeScore == predictedHomeScore) &&
            (identical(other.predictedAwayScore, predictedAwayScore) ||
                other.predictedAwayScore == predictedAwayScore) &&
            (identical(other.stake, stake) || other.stake == stake) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.payout, payout) || other.payout == payout));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    poolId,
    userId,
    userName,
    predictedHomeScore,
    predictedAwayScore,
    stake,
    status,
    payout,
  );

  /// Create a copy of PoolEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PoolEntryImplCopyWith<_$PoolEntryImpl> get copyWith =>
      __$$PoolEntryImplCopyWithImpl<_$PoolEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PoolEntryImplToJson(this);
  }
}

abstract class _PoolEntry implements PoolEntry {
  const factory _PoolEntry({
    required final String id,
    required final String poolId,
    required final String userId,
    required final String userName,
    required final int predictedHomeScore,
    required final int predictedAwayScore,
    required final int stake,
    required final String status,
    required final int payout,
  }) = _$PoolEntryImpl;

  factory _PoolEntry.fromJson(Map<String, dynamic> json) =
      _$PoolEntryImpl.fromJson;

  @override
  String get id;
  @override
  String get poolId;
  @override
  String get userId;
  @override
  String get userName;
  @override
  int get predictedHomeScore;
  @override
  int get predictedAwayScore;
  @override
  int get stake;
  @override
  String get status; // 'active' | 'winner' | 'loser' | 'refunded'
  @override
  int get payout;

  /// Create a copy of PoolEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PoolEntryImplCopyWith<_$PoolEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
