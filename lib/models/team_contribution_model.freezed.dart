// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_contribution_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TeamContributionModel _$TeamContributionModelFromJson(
  Map<String, dynamic> json,
) {
  return _TeamContributionModel.fromJson(json);
}

/// @nodoc
mixin _$TeamContributionModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'contribution_type')
  String get contributionType => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_fet')
  int? get amountFet => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_money')
  double? get amountMoney => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_code')
  String? get currencyCode => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get provider => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this TeamContributionModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeamContributionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamContributionModelCopyWith<TeamContributionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamContributionModelCopyWith<$Res> {
  factory $TeamContributionModelCopyWith(
    TeamContributionModel value,
    $Res Function(TeamContributionModel) then,
  ) = _$TeamContributionModelCopyWithImpl<$Res, TeamContributionModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'contribution_type') String contributionType,
    @JsonKey(name: 'amount_fet') int? amountFet,
    @JsonKey(name: 'amount_money') double? amountMoney,
    @JsonKey(name: 'currency_code') String? currencyCode,
    String status,
    String? provider,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class _$TeamContributionModelCopyWithImpl<
  $Res,
  $Val extends TeamContributionModel
>
    implements $TeamContributionModelCopyWith<$Res> {
  _$TeamContributionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamContributionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? contributionType = null,
    Object? amountFet = freezed,
    Object? amountMoney = freezed,
    Object? currencyCode = freezed,
    Object? status = null,
    Object? provider = freezed,
    Object? createdAt = null,
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
            contributionType: null == contributionType
                ? _value.contributionType
                : contributionType // ignore: cast_nullable_to_non_nullable
                      as String,
            amountFet: freezed == amountFet
                ? _value.amountFet
                : amountFet // ignore: cast_nullable_to_non_nullable
                      as int?,
            amountMoney: freezed == amountMoney
                ? _value.amountMoney
                : amountMoney // ignore: cast_nullable_to_non_nullable
                      as double?,
            currencyCode: freezed == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            provider: freezed == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TeamContributionModelImplCopyWith<$Res>
    implements $TeamContributionModelCopyWith<$Res> {
  factory _$$TeamContributionModelImplCopyWith(
    _$TeamContributionModelImpl value,
    $Res Function(_$TeamContributionModelImpl) then,
  ) = __$$TeamContributionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'contribution_type') String contributionType,
    @JsonKey(name: 'amount_fet') int? amountFet,
    @JsonKey(name: 'amount_money') double? amountMoney,
    @JsonKey(name: 'currency_code') String? currencyCode,
    String status,
    String? provider,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class __$$TeamContributionModelImplCopyWithImpl<$Res>
    extends
        _$TeamContributionModelCopyWithImpl<$Res, _$TeamContributionModelImpl>
    implements _$$TeamContributionModelImplCopyWith<$Res> {
  __$$TeamContributionModelImplCopyWithImpl(
    _$TeamContributionModelImpl _value,
    $Res Function(_$TeamContributionModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamContributionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? contributionType = null,
    Object? amountFet = freezed,
    Object? amountMoney = freezed,
    Object? currencyCode = freezed,
    Object? status = null,
    Object? provider = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$TeamContributionModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        contributionType: null == contributionType
            ? _value.contributionType
            : contributionType // ignore: cast_nullable_to_non_nullable
                  as String,
        amountFet: freezed == amountFet
            ? _value.amountFet
            : amountFet // ignore: cast_nullable_to_non_nullable
                  as int?,
        amountMoney: freezed == amountMoney
            ? _value.amountMoney
            : amountMoney // ignore: cast_nullable_to_non_nullable
                  as double?,
        currencyCode: freezed == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        provider: freezed == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TeamContributionModelImpl implements _TeamContributionModel {
  const _$TeamContributionModelImpl({
    required this.id,
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'contribution_type') required this.contributionType,
    @JsonKey(name: 'amount_fet') this.amountFet,
    @JsonKey(name: 'amount_money') this.amountMoney,
    @JsonKey(name: 'currency_code') this.currencyCode,
    required this.status,
    this.provider,
    @JsonKey(name: 'created_at') required this.createdAt,
  });

  factory _$TeamContributionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeamContributionModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'contribution_type')
  final String contributionType;
  @override
  @JsonKey(name: 'amount_fet')
  final int? amountFet;
  @override
  @JsonKey(name: 'amount_money')
  final double? amountMoney;
  @override
  @JsonKey(name: 'currency_code')
  final String? currencyCode;
  @override
  final String status;
  @override
  final String? provider;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'TeamContributionModel(id: $id, teamId: $teamId, contributionType: $contributionType, amountFet: $amountFet, amountMoney: $amountMoney, currencyCode: $currencyCode, status: $status, provider: $provider, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamContributionModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.contributionType, contributionType) ||
                other.contributionType == contributionType) &&
            (identical(other.amountFet, amountFet) ||
                other.amountFet == amountFet) &&
            (identical(other.amountMoney, amountMoney) ||
                other.amountMoney == amountMoney) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    teamId,
    contributionType,
    amountFet,
    amountMoney,
    currencyCode,
    status,
    provider,
    createdAt,
  );

  /// Create a copy of TeamContributionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamContributionModelImplCopyWith<_$TeamContributionModelImpl>
  get copyWith =>
      __$$TeamContributionModelImplCopyWithImpl<_$TeamContributionModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TeamContributionModelImplToJson(this);
  }
}

abstract class _TeamContributionModel implements TeamContributionModel {
  const factory _TeamContributionModel({
    required final String id,
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'contribution_type') required final String contributionType,
    @JsonKey(name: 'amount_fet') final int? amountFet,
    @JsonKey(name: 'amount_money') final double? amountMoney,
    @JsonKey(name: 'currency_code') final String? currencyCode,
    required final String status,
    final String? provider,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
  }) = _$TeamContributionModelImpl;

  factory _TeamContributionModel.fromJson(Map<String, dynamic> json) =
      _$TeamContributionModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'contribution_type')
  String get contributionType;
  @override
  @JsonKey(name: 'amount_fet')
  int? get amountFet;
  @override
  @JsonKey(name: 'amount_money')
  double? get amountMoney;
  @override
  @JsonKey(name: 'currency_code')
  String? get currencyCode;
  @override
  String get status;
  @override
  String? get provider;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of TeamContributionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamContributionModelImplCopyWith<_$TeamContributionModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}

TeamCommunityStats _$TeamCommunityStatsFromJson(Map<String, dynamic> json) {
  return _TeamCommunityStats.fromJson(json);
}

/// @nodoc
mixin _$TeamCommunityStats {
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_name')
  String get teamName => throw _privateConstructorUsedError;
  @JsonKey(name: 'fan_count')
  int get fanCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_fet_contributed')
  int get totalFetContributed => throw _privateConstructorUsedError;
  @JsonKey(name: 'contribution_count')
  int get contributionCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'supporters_last_30d')
  int get supportersLast30d => throw _privateConstructorUsedError;

  /// Serializes this TeamCommunityStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeamCommunityStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamCommunityStatsCopyWith<TeamCommunityStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamCommunityStatsCopyWith<$Res> {
  factory $TeamCommunityStatsCopyWith(
    TeamCommunityStats value,
    $Res Function(TeamCommunityStats) then,
  ) = _$TeamCommunityStatsCopyWithImpl<$Res, TeamCommunityStats>;
  @useResult
  $Res call({
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'team_name') String teamName,
    @JsonKey(name: 'fan_count') int fanCount,
    @JsonKey(name: 'total_fet_contributed') int totalFetContributed,
    @JsonKey(name: 'contribution_count') int contributionCount,
    @JsonKey(name: 'supporters_last_30d') int supportersLast30d,
  });
}

/// @nodoc
class _$TeamCommunityStatsCopyWithImpl<$Res, $Val extends TeamCommunityStats>
    implements $TeamCommunityStatsCopyWith<$Res> {
  _$TeamCommunityStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamCommunityStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? teamName = null,
    Object? fanCount = null,
    Object? totalFetContributed = null,
    Object? contributionCount = null,
    Object? supportersLast30d = null,
  }) {
    return _then(
      _value.copyWith(
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            teamName: null == teamName
                ? _value.teamName
                : teamName // ignore: cast_nullable_to_non_nullable
                      as String,
            fanCount: null == fanCount
                ? _value.fanCount
                : fanCount // ignore: cast_nullable_to_non_nullable
                      as int,
            totalFetContributed: null == totalFetContributed
                ? _value.totalFetContributed
                : totalFetContributed // ignore: cast_nullable_to_non_nullable
                      as int,
            contributionCount: null == contributionCount
                ? _value.contributionCount
                : contributionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            supportersLast30d: null == supportersLast30d
                ? _value.supportersLast30d
                : supportersLast30d // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TeamCommunityStatsImplCopyWith<$Res>
    implements $TeamCommunityStatsCopyWith<$Res> {
  factory _$$TeamCommunityStatsImplCopyWith(
    _$TeamCommunityStatsImpl value,
    $Res Function(_$TeamCommunityStatsImpl) then,
  ) = __$$TeamCommunityStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'team_name') String teamName,
    @JsonKey(name: 'fan_count') int fanCount,
    @JsonKey(name: 'total_fet_contributed') int totalFetContributed,
    @JsonKey(name: 'contribution_count') int contributionCount,
    @JsonKey(name: 'supporters_last_30d') int supportersLast30d,
  });
}

/// @nodoc
class __$$TeamCommunityStatsImplCopyWithImpl<$Res>
    extends _$TeamCommunityStatsCopyWithImpl<$Res, _$TeamCommunityStatsImpl>
    implements _$$TeamCommunityStatsImplCopyWith<$Res> {
  __$$TeamCommunityStatsImplCopyWithImpl(
    _$TeamCommunityStatsImpl _value,
    $Res Function(_$TeamCommunityStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamCommunityStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? teamName = null,
    Object? fanCount = null,
    Object? totalFetContributed = null,
    Object? contributionCount = null,
    Object? supportersLast30d = null,
  }) {
    return _then(
      _$TeamCommunityStatsImpl(
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        teamName: null == teamName
            ? _value.teamName
            : teamName // ignore: cast_nullable_to_non_nullable
                  as String,
        fanCount: null == fanCount
            ? _value.fanCount
            : fanCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalFetContributed: null == totalFetContributed
            ? _value.totalFetContributed
            : totalFetContributed // ignore: cast_nullable_to_non_nullable
                  as int,
        contributionCount: null == contributionCount
            ? _value.contributionCount
            : contributionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        supportersLast30d: null == supportersLast30d
            ? _value.supportersLast30d
            : supportersLast30d // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TeamCommunityStatsImpl implements _TeamCommunityStats {
  const _$TeamCommunityStatsImpl({
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'team_name') required this.teamName,
    @JsonKey(name: 'fan_count') this.fanCount = 0,
    @JsonKey(name: 'total_fet_contributed') this.totalFetContributed = 0,
    @JsonKey(name: 'contribution_count') this.contributionCount = 0,
    @JsonKey(name: 'supporters_last_30d') this.supportersLast30d = 0,
  });

  factory _$TeamCommunityStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeamCommunityStatsImplFromJson(json);

  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'team_name')
  final String teamName;
  @override
  @JsonKey(name: 'fan_count')
  final int fanCount;
  @override
  @JsonKey(name: 'total_fet_contributed')
  final int totalFetContributed;
  @override
  @JsonKey(name: 'contribution_count')
  final int contributionCount;
  @override
  @JsonKey(name: 'supporters_last_30d')
  final int supportersLast30d;

  @override
  String toString() {
    return 'TeamCommunityStats(teamId: $teamId, teamName: $teamName, fanCount: $fanCount, totalFetContributed: $totalFetContributed, contributionCount: $contributionCount, supportersLast30d: $supportersLast30d)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamCommunityStatsImpl &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.teamName, teamName) ||
                other.teamName == teamName) &&
            (identical(other.fanCount, fanCount) ||
                other.fanCount == fanCount) &&
            (identical(other.totalFetContributed, totalFetContributed) ||
                other.totalFetContributed == totalFetContributed) &&
            (identical(other.contributionCount, contributionCount) ||
                other.contributionCount == contributionCount) &&
            (identical(other.supportersLast30d, supportersLast30d) ||
                other.supportersLast30d == supportersLast30d));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    teamId,
    teamName,
    fanCount,
    totalFetContributed,
    contributionCount,
    supportersLast30d,
  );

  /// Create a copy of TeamCommunityStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamCommunityStatsImplCopyWith<_$TeamCommunityStatsImpl> get copyWith =>
      __$$TeamCommunityStatsImplCopyWithImpl<_$TeamCommunityStatsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TeamCommunityStatsImplToJson(this);
  }
}

abstract class _TeamCommunityStats implements TeamCommunityStats {
  const factory _TeamCommunityStats({
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'team_name') required final String teamName,
    @JsonKey(name: 'fan_count') final int fanCount,
    @JsonKey(name: 'total_fet_contributed') final int totalFetContributed,
    @JsonKey(name: 'contribution_count') final int contributionCount,
    @JsonKey(name: 'supporters_last_30d') final int supportersLast30d,
  }) = _$TeamCommunityStatsImpl;

  factory _TeamCommunityStats.fromJson(Map<String, dynamic> json) =
      _$TeamCommunityStatsImpl.fromJson;

  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'team_name')
  String get teamName;
  @override
  @JsonKey(name: 'fan_count')
  int get fanCount;
  @override
  @JsonKey(name: 'total_fet_contributed')
  int get totalFetContributed;
  @override
  @JsonKey(name: 'contribution_count')
  int get contributionCount;
  @override
  @JsonKey(name: 'supporters_last_30d')
  int get supportersLast30d;

  /// Create a copy of TeamCommunityStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamCommunityStatsImplCopyWith<_$TeamCommunityStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
