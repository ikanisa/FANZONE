// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_challenge_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DailyChallenge _$DailyChallengeFromJson(Map<String, dynamic> json) {
  return _DailyChallenge.fromJson(json);
}

/// @nodoc
mixin _$DailyChallenge {
  String get id => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  String get matchId => throw _privateConstructorUsedError;
  String get matchName => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get rewardFet => throw _privateConstructorUsedError;
  int get bonusExactFet => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // 'active' | 'settled' | 'cancelled'
  int? get officialHomeScore => throw _privateConstructorUsedError;
  int? get officialAwayScore => throw _privateConstructorUsedError;
  int get totalEntries => throw _privateConstructorUsedError;
  int get totalWinners => throw _privateConstructorUsedError;

  /// Serializes this DailyChallenge to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyChallenge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyChallengeCopyWith<DailyChallenge> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyChallengeCopyWith<$Res> {
  factory $DailyChallengeCopyWith(
    DailyChallenge value,
    $Res Function(DailyChallenge) then,
  ) = _$DailyChallengeCopyWithImpl<$Res, DailyChallenge>;
  @useResult
  $Res call({
    String id,
    DateTime date,
    String matchId,
    String matchName,
    String title,
    String description,
    int rewardFet,
    int bonusExactFet,
    String status,
    int? officialHomeScore,
    int? officialAwayScore,
    int totalEntries,
    int totalWinners,
  });
}

/// @nodoc
class _$DailyChallengeCopyWithImpl<$Res, $Val extends DailyChallenge>
    implements $DailyChallengeCopyWith<$Res> {
  _$DailyChallengeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyChallenge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? matchId = null,
    Object? matchName = null,
    Object? title = null,
    Object? description = null,
    Object? rewardFet = null,
    Object? bonusExactFet = null,
    Object? status = null,
    Object? officialHomeScore = freezed,
    Object? officialAwayScore = freezed,
    Object? totalEntries = null,
    Object? totalWinners = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            matchId: null == matchId
                ? _value.matchId
                : matchId // ignore: cast_nullable_to_non_nullable
                      as String,
            matchName: null == matchName
                ? _value.matchName
                : matchName // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            rewardFet: null == rewardFet
                ? _value.rewardFet
                : rewardFet // ignore: cast_nullable_to_non_nullable
                      as int,
            bonusExactFet: null == bonusExactFet
                ? _value.bonusExactFet
                : bonusExactFet // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            officialHomeScore: freezed == officialHomeScore
                ? _value.officialHomeScore
                : officialHomeScore // ignore: cast_nullable_to_non_nullable
                      as int?,
            officialAwayScore: freezed == officialAwayScore
                ? _value.officialAwayScore
                : officialAwayScore // ignore: cast_nullable_to_non_nullable
                      as int?,
            totalEntries: null == totalEntries
                ? _value.totalEntries
                : totalEntries // ignore: cast_nullable_to_non_nullable
                      as int,
            totalWinners: null == totalWinners
                ? _value.totalWinners
                : totalWinners // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DailyChallengeImplCopyWith<$Res>
    implements $DailyChallengeCopyWith<$Res> {
  factory _$$DailyChallengeImplCopyWith(
    _$DailyChallengeImpl value,
    $Res Function(_$DailyChallengeImpl) then,
  ) = __$$DailyChallengeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    DateTime date,
    String matchId,
    String matchName,
    String title,
    String description,
    int rewardFet,
    int bonusExactFet,
    String status,
    int? officialHomeScore,
    int? officialAwayScore,
    int totalEntries,
    int totalWinners,
  });
}

/// @nodoc
class __$$DailyChallengeImplCopyWithImpl<$Res>
    extends _$DailyChallengeCopyWithImpl<$Res, _$DailyChallengeImpl>
    implements _$$DailyChallengeImplCopyWith<$Res> {
  __$$DailyChallengeImplCopyWithImpl(
    _$DailyChallengeImpl _value,
    $Res Function(_$DailyChallengeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyChallenge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? matchId = null,
    Object? matchName = null,
    Object? title = null,
    Object? description = null,
    Object? rewardFet = null,
    Object? bonusExactFet = null,
    Object? status = null,
    Object? officialHomeScore = freezed,
    Object? officialAwayScore = freezed,
    Object? totalEntries = null,
    Object? totalWinners = null,
  }) {
    return _then(
      _$DailyChallengeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        matchId: null == matchId
            ? _value.matchId
            : matchId // ignore: cast_nullable_to_non_nullable
                  as String,
        matchName: null == matchName
            ? _value.matchName
            : matchName // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        rewardFet: null == rewardFet
            ? _value.rewardFet
            : rewardFet // ignore: cast_nullable_to_non_nullable
                  as int,
        bonusExactFet: null == bonusExactFet
            ? _value.bonusExactFet
            : bonusExactFet // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        officialHomeScore: freezed == officialHomeScore
            ? _value.officialHomeScore
            : officialHomeScore // ignore: cast_nullable_to_non_nullable
                  as int?,
        officialAwayScore: freezed == officialAwayScore
            ? _value.officialAwayScore
            : officialAwayScore // ignore: cast_nullable_to_non_nullable
                  as int?,
        totalEntries: null == totalEntries
            ? _value.totalEntries
            : totalEntries // ignore: cast_nullable_to_non_nullable
                  as int,
        totalWinners: null == totalWinners
            ? _value.totalWinners
            : totalWinners // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyChallengeImpl implements _DailyChallenge {
  const _$DailyChallengeImpl({
    required this.id,
    required this.date,
    required this.matchId,
    required this.matchName,
    required this.title,
    this.description = '',
    required this.rewardFet,
    required this.bonusExactFet,
    required this.status,
    this.officialHomeScore,
    this.officialAwayScore,
    this.totalEntries = 0,
    this.totalWinners = 0,
  });

  factory _$DailyChallengeImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyChallengeImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime date;
  @override
  final String matchId;
  @override
  final String matchName;
  @override
  final String title;
  @override
  @JsonKey()
  final String description;
  @override
  final int rewardFet;
  @override
  final int bonusExactFet;
  @override
  final String status;
  // 'active' | 'settled' | 'cancelled'
  @override
  final int? officialHomeScore;
  @override
  final int? officialAwayScore;
  @override
  @JsonKey()
  final int totalEntries;
  @override
  @JsonKey()
  final int totalWinners;

  @override
  String toString() {
    return 'DailyChallenge(id: $id, date: $date, matchId: $matchId, matchName: $matchName, title: $title, description: $description, rewardFet: $rewardFet, bonusExactFet: $bonusExactFet, status: $status, officialHomeScore: $officialHomeScore, officialAwayScore: $officialAwayScore, totalEntries: $totalEntries, totalWinners: $totalWinners)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyChallengeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.matchId, matchId) || other.matchId == matchId) &&
            (identical(other.matchName, matchName) ||
                other.matchName == matchName) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.rewardFet, rewardFet) ||
                other.rewardFet == rewardFet) &&
            (identical(other.bonusExactFet, bonusExactFet) ||
                other.bonusExactFet == bonusExactFet) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.officialHomeScore, officialHomeScore) ||
                other.officialHomeScore == officialHomeScore) &&
            (identical(other.officialAwayScore, officialAwayScore) ||
                other.officialAwayScore == officialAwayScore) &&
            (identical(other.totalEntries, totalEntries) ||
                other.totalEntries == totalEntries) &&
            (identical(other.totalWinners, totalWinners) ||
                other.totalWinners == totalWinners));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    date,
    matchId,
    matchName,
    title,
    description,
    rewardFet,
    bonusExactFet,
    status,
    officialHomeScore,
    officialAwayScore,
    totalEntries,
    totalWinners,
  );

  /// Create a copy of DailyChallenge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyChallengeImplCopyWith<_$DailyChallengeImpl> get copyWith =>
      __$$DailyChallengeImplCopyWithImpl<_$DailyChallengeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyChallengeImplToJson(this);
  }
}

abstract class _DailyChallenge implements DailyChallenge {
  const factory _DailyChallenge({
    required final String id,
    required final DateTime date,
    required final String matchId,
    required final String matchName,
    required final String title,
    final String description,
    required final int rewardFet,
    required final int bonusExactFet,
    required final String status,
    final int? officialHomeScore,
    final int? officialAwayScore,
    final int totalEntries,
    final int totalWinners,
  }) = _$DailyChallengeImpl;

  factory _DailyChallenge.fromJson(Map<String, dynamic> json) =
      _$DailyChallengeImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get date;
  @override
  String get matchId;
  @override
  String get matchName;
  @override
  String get title;
  @override
  String get description;
  @override
  int get rewardFet;
  @override
  int get bonusExactFet;
  @override
  String get status; // 'active' | 'settled' | 'cancelled'
  @override
  int? get officialHomeScore;
  @override
  int? get officialAwayScore;
  @override
  int get totalEntries;
  @override
  int get totalWinners;

  /// Create a copy of DailyChallenge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyChallengeImplCopyWith<_$DailyChallengeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DailyChallengeEntry _$DailyChallengeEntryFromJson(Map<String, dynamic> json) {
  return _DailyChallengeEntry.fromJson(json);
}

/// @nodoc
mixin _$DailyChallengeEntry {
  String get id => throw _privateConstructorUsedError;
  String get challengeId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  int get predictedHomeScore => throw _privateConstructorUsedError;
  int get predictedAwayScore => throw _privateConstructorUsedError;
  String get result =>
      throw _privateConstructorUsedError; // 'pending' | 'correct_result' | 'exact_score' | 'wrong'
  int get payoutFet => throw _privateConstructorUsedError;
  DateTime? get submittedAt => throw _privateConstructorUsedError;

  /// Serializes this DailyChallengeEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyChallengeEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyChallengeEntryCopyWith<DailyChallengeEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyChallengeEntryCopyWith<$Res> {
  factory $DailyChallengeEntryCopyWith(
    DailyChallengeEntry value,
    $Res Function(DailyChallengeEntry) then,
  ) = _$DailyChallengeEntryCopyWithImpl<$Res, DailyChallengeEntry>;
  @useResult
  $Res call({
    String id,
    String challengeId,
    String userId,
    int predictedHomeScore,
    int predictedAwayScore,
    String result,
    int payoutFet,
    DateTime? submittedAt,
  });
}

/// @nodoc
class _$DailyChallengeEntryCopyWithImpl<$Res, $Val extends DailyChallengeEntry>
    implements $DailyChallengeEntryCopyWith<$Res> {
  _$DailyChallengeEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyChallengeEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? challengeId = null,
    Object? userId = null,
    Object? predictedHomeScore = null,
    Object? predictedAwayScore = null,
    Object? result = null,
    Object? payoutFet = null,
    Object? submittedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            challengeId: null == challengeId
                ? _value.challengeId
                : challengeId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            predictedHomeScore: null == predictedHomeScore
                ? _value.predictedHomeScore
                : predictedHomeScore // ignore: cast_nullable_to_non_nullable
                      as int,
            predictedAwayScore: null == predictedAwayScore
                ? _value.predictedAwayScore
                : predictedAwayScore // ignore: cast_nullable_to_non_nullable
                      as int,
            result: null == result
                ? _value.result
                : result // ignore: cast_nullable_to_non_nullable
                      as String,
            payoutFet: null == payoutFet
                ? _value.payoutFet
                : payoutFet // ignore: cast_nullable_to_non_nullable
                      as int,
            submittedAt: freezed == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DailyChallengeEntryImplCopyWith<$Res>
    implements $DailyChallengeEntryCopyWith<$Res> {
  factory _$$DailyChallengeEntryImplCopyWith(
    _$DailyChallengeEntryImpl value,
    $Res Function(_$DailyChallengeEntryImpl) then,
  ) = __$$DailyChallengeEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String challengeId,
    String userId,
    int predictedHomeScore,
    int predictedAwayScore,
    String result,
    int payoutFet,
    DateTime? submittedAt,
  });
}

/// @nodoc
class __$$DailyChallengeEntryImplCopyWithImpl<$Res>
    extends _$DailyChallengeEntryCopyWithImpl<$Res, _$DailyChallengeEntryImpl>
    implements _$$DailyChallengeEntryImplCopyWith<$Res> {
  __$$DailyChallengeEntryImplCopyWithImpl(
    _$DailyChallengeEntryImpl _value,
    $Res Function(_$DailyChallengeEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyChallengeEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? challengeId = null,
    Object? userId = null,
    Object? predictedHomeScore = null,
    Object? predictedAwayScore = null,
    Object? result = null,
    Object? payoutFet = null,
    Object? submittedAt = freezed,
  }) {
    return _then(
      _$DailyChallengeEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        challengeId: null == challengeId
            ? _value.challengeId
            : challengeId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        predictedHomeScore: null == predictedHomeScore
            ? _value.predictedHomeScore
            : predictedHomeScore // ignore: cast_nullable_to_non_nullable
                  as int,
        predictedAwayScore: null == predictedAwayScore
            ? _value.predictedAwayScore
            : predictedAwayScore // ignore: cast_nullable_to_non_nullable
                  as int,
        result: null == result
            ? _value.result
            : result // ignore: cast_nullable_to_non_nullable
                  as String,
        payoutFet: null == payoutFet
            ? _value.payoutFet
            : payoutFet // ignore: cast_nullable_to_non_nullable
                  as int,
        submittedAt: freezed == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyChallengeEntryImpl implements _DailyChallengeEntry {
  const _$DailyChallengeEntryImpl({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.predictedHomeScore,
    required this.predictedAwayScore,
    required this.result,
    this.payoutFet = 0,
    this.submittedAt,
  });

  factory _$DailyChallengeEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyChallengeEntryImplFromJson(json);

  @override
  final String id;
  @override
  final String challengeId;
  @override
  final String userId;
  @override
  final int predictedHomeScore;
  @override
  final int predictedAwayScore;
  @override
  final String result;
  // 'pending' | 'correct_result' | 'exact_score' | 'wrong'
  @override
  @JsonKey()
  final int payoutFet;
  @override
  final DateTime? submittedAt;

  @override
  String toString() {
    return 'DailyChallengeEntry(id: $id, challengeId: $challengeId, userId: $userId, predictedHomeScore: $predictedHomeScore, predictedAwayScore: $predictedAwayScore, result: $result, payoutFet: $payoutFet, submittedAt: $submittedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyChallengeEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.challengeId, challengeId) ||
                other.challengeId == challengeId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.predictedHomeScore, predictedHomeScore) ||
                other.predictedHomeScore == predictedHomeScore) &&
            (identical(other.predictedAwayScore, predictedAwayScore) ||
                other.predictedAwayScore == predictedAwayScore) &&
            (identical(other.result, result) || other.result == result) &&
            (identical(other.payoutFet, payoutFet) ||
                other.payoutFet == payoutFet) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    challengeId,
    userId,
    predictedHomeScore,
    predictedAwayScore,
    result,
    payoutFet,
    submittedAt,
  );

  /// Create a copy of DailyChallengeEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyChallengeEntryImplCopyWith<_$DailyChallengeEntryImpl> get copyWith =>
      __$$DailyChallengeEntryImplCopyWithImpl<_$DailyChallengeEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyChallengeEntryImplToJson(this);
  }
}

abstract class _DailyChallengeEntry implements DailyChallengeEntry {
  const factory _DailyChallengeEntry({
    required final String id,
    required final String challengeId,
    required final String userId,
    required final int predictedHomeScore,
    required final int predictedAwayScore,
    required final String result,
    final int payoutFet,
    final DateTime? submittedAt,
  }) = _$DailyChallengeEntryImpl;

  factory _DailyChallengeEntry.fromJson(Map<String, dynamic> json) =
      _$DailyChallengeEntryImpl.fromJson;

  @override
  String get id;
  @override
  String get challengeId;
  @override
  String get userId;
  @override
  int get predictedHomeScore;
  @override
  int get predictedAwayScore;
  @override
  String get result; // 'pending' | 'correct_result' | 'exact_score' | 'wrong'
  @override
  int get payoutFet;
  @override
  DateTime? get submittedAt;

  /// Create a copy of DailyChallengeEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyChallengeEntryImplCopyWith<_$DailyChallengeEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
