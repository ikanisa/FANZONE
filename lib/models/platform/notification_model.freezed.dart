// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NotificationItem _$NotificationItemFromJson(Map<String, dynamic> json) {
  return _NotificationItem.fromJson(json);
}

/// @nodoc
mixin _$NotificationItem {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  Map<String, dynamic> get data => throw _privateConstructorUsedError;
  @JsonKey(name: 'sent_at')
  DateTime get sentAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'read_at')
  DateTime? get readAt => throw _privateConstructorUsedError;

  /// Serializes this NotificationItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationItemCopyWith<NotificationItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationItemCopyWith<$Res> {
  factory $NotificationItemCopyWith(
    NotificationItem value,
    $Res Function(NotificationItem) then,
  ) = _$NotificationItemCopyWithImpl<$Res, NotificationItem>;
  @useResult
  $Res call({
    String id,
    String type,
    String title,
    String body,
    Map<String, dynamic> data,
    @JsonKey(name: 'sent_at') DateTime sentAt,
    @JsonKey(name: 'read_at') DateTime? readAt,
  });
}

/// @nodoc
class _$NotificationItemCopyWithImpl<$Res, $Val extends NotificationItem>
    implements $NotificationItemCopyWith<$Res> {
  _$NotificationItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? body = null,
    Object? data = null,
    Object? sentAt = null,
    Object? readAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            body: null == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String,
            data: null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            sentAt: null == sentAt
                ? _value.sentAt
                : sentAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            readAt: freezed == readAt
                ? _value.readAt
                : readAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationItemImplCopyWith<$Res>
    implements $NotificationItemCopyWith<$Res> {
  factory _$$NotificationItemImplCopyWith(
    _$NotificationItemImpl value,
    $Res Function(_$NotificationItemImpl) then,
  ) = __$$NotificationItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String type,
    String title,
    String body,
    Map<String, dynamic> data,
    @JsonKey(name: 'sent_at') DateTime sentAt,
    @JsonKey(name: 'read_at') DateTime? readAt,
  });
}

/// @nodoc
class __$$NotificationItemImplCopyWithImpl<$Res>
    extends _$NotificationItemCopyWithImpl<$Res, _$NotificationItemImpl>
    implements _$$NotificationItemImplCopyWith<$Res> {
  __$$NotificationItemImplCopyWithImpl(
    _$NotificationItemImpl _value,
    $Res Function(_$NotificationItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? body = null,
    Object? data = null,
    Object? sentAt = null,
    Object? readAt = freezed,
  }) {
    return _then(
      _$NotificationItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        body: null == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        data: null == data
            ? _value._data
            : data // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        sentAt: null == sentAt
            ? _value.sentAt
            : sentAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        readAt: freezed == readAt
            ? _value.readAt
            : readAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationItemImpl implements _NotificationItem {
  const _$NotificationItemImpl({
    required this.id,
    required this.type,
    required this.title,
    this.body = '',
    final Map<String, dynamic> data = const {},
    @JsonKey(name: 'sent_at') required this.sentAt,
    @JsonKey(name: 'read_at') this.readAt,
  }) : _data = data;

  factory _$NotificationItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationItemImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
  @override
  final String title;
  @override
  @JsonKey()
  final String body;
  final Map<String, dynamic> _data;
  @override
  @JsonKey()
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  @override
  @JsonKey(name: 'sent_at')
  final DateTime sentAt;
  @override
  @JsonKey(name: 'read_at')
  final DateTime? readAt;

  @override
  String toString() {
    return 'NotificationItem(id: $id, type: $type, title: $title, body: $body, data: $data, sentAt: $sentAt, readAt: $readAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body) &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.sentAt, sentAt) || other.sentAt == sentAt) &&
            (identical(other.readAt, readAt) || other.readAt == readAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    title,
    body,
    const DeepCollectionEquality().hash(_data),
    sentAt,
    readAt,
  );

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationItemImplCopyWith<_$NotificationItemImpl> get copyWith =>
      __$$NotificationItemImplCopyWithImpl<_$NotificationItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationItemImplToJson(this);
  }
}

abstract class _NotificationItem implements NotificationItem {
  const factory _NotificationItem({
    required final String id,
    required final String type,
    required final String title,
    final String body,
    final Map<String, dynamic> data,
    @JsonKey(name: 'sent_at') required final DateTime sentAt,
    @JsonKey(name: 'read_at') final DateTime? readAt,
  }) = _$NotificationItemImpl;

  factory _NotificationItem.fromJson(Map<String, dynamic> json) =
      _$NotificationItemImpl.fromJson;

  @override
  String get id;
  @override
  String get type;
  @override
  String get title;
  @override
  String get body;
  @override
  Map<String, dynamic> get data;
  @override
  @JsonKey(name: 'sent_at')
  DateTime get sentAt;
  @override
  @JsonKey(name: 'read_at')
  DateTime? get readAt;

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationItemImplCopyWith<_$NotificationItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NotificationPreferences _$NotificationPreferencesFromJson(
  Map<String, dynamic> json,
) {
  return _NotificationPreferences.fromJson(json);
}

/// @nodoc
mixin _$NotificationPreferences {
  @JsonKey(name: 'goal_alerts')
  bool get goalAlerts => throw _privateConstructorUsedError;
  @JsonKey(name: 'prediction_updates')
  bool get predictionUpdates => throw _privateConstructorUsedError;
  @JsonKey(name: 'reward_updates')
  bool get rewardUpdates => throw _privateConstructorUsedError;
  @JsonKey(name: 'marketing')
  bool get marketing => throw _privateConstructorUsedError;

  /// Serializes this NotificationPreferences to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationPreferencesCopyWith<NotificationPreferences> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationPreferencesCopyWith<$Res> {
  factory $NotificationPreferencesCopyWith(
    NotificationPreferences value,
    $Res Function(NotificationPreferences) then,
  ) = _$NotificationPreferencesCopyWithImpl<$Res, NotificationPreferences>;
  @useResult
  $Res call({
    @JsonKey(name: 'goal_alerts') bool goalAlerts,
    @JsonKey(name: 'prediction_updates') bool predictionUpdates,
    @JsonKey(name: 'reward_updates') bool rewardUpdates,
    @JsonKey(name: 'marketing') bool marketing,
  });
}

/// @nodoc
class _$NotificationPreferencesCopyWithImpl<
  $Res,
  $Val extends NotificationPreferences
>
    implements $NotificationPreferencesCopyWith<$Res> {
  _$NotificationPreferencesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalAlerts = null,
    Object? predictionUpdates = null,
    Object? rewardUpdates = null,
    Object? marketing = null,
  }) {
    return _then(
      _value.copyWith(
            goalAlerts: null == goalAlerts
                ? _value.goalAlerts
                : goalAlerts // ignore: cast_nullable_to_non_nullable
                      as bool,
            predictionUpdates: null == predictionUpdates
                ? _value.predictionUpdates
                : predictionUpdates // ignore: cast_nullable_to_non_nullable
                      as bool,
            rewardUpdates: null == rewardUpdates
                ? _value.rewardUpdates
                : rewardUpdates // ignore: cast_nullable_to_non_nullable
                      as bool,
            marketing: null == marketing
                ? _value.marketing
                : marketing // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationPreferencesImplCopyWith<$Res>
    implements $NotificationPreferencesCopyWith<$Res> {
  factory _$$NotificationPreferencesImplCopyWith(
    _$NotificationPreferencesImpl value,
    $Res Function(_$NotificationPreferencesImpl) then,
  ) = __$$NotificationPreferencesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'goal_alerts') bool goalAlerts,
    @JsonKey(name: 'prediction_updates') bool predictionUpdates,
    @JsonKey(name: 'reward_updates') bool rewardUpdates,
    @JsonKey(name: 'marketing') bool marketing,
  });
}

/// @nodoc
class __$$NotificationPreferencesImplCopyWithImpl<$Res>
    extends
        _$NotificationPreferencesCopyWithImpl<
          $Res,
          _$NotificationPreferencesImpl
        >
    implements _$$NotificationPreferencesImplCopyWith<$Res> {
  __$$NotificationPreferencesImplCopyWithImpl(
    _$NotificationPreferencesImpl _value,
    $Res Function(_$NotificationPreferencesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalAlerts = null,
    Object? predictionUpdates = null,
    Object? rewardUpdates = null,
    Object? marketing = null,
  }) {
    return _then(
      _$NotificationPreferencesImpl(
        goalAlerts: null == goalAlerts
            ? _value.goalAlerts
            : goalAlerts // ignore: cast_nullable_to_non_nullable
                  as bool,
        predictionUpdates: null == predictionUpdates
            ? _value.predictionUpdates
            : predictionUpdates // ignore: cast_nullable_to_non_nullable
                  as bool,
        rewardUpdates: null == rewardUpdates
            ? _value.rewardUpdates
            : rewardUpdates // ignore: cast_nullable_to_non_nullable
                  as bool,
        marketing: null == marketing
            ? _value.marketing
            : marketing // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationPreferencesImpl implements _NotificationPreferences {
  const _$NotificationPreferencesImpl({
    @JsonKey(name: 'goal_alerts') this.goalAlerts = true,
    @JsonKey(name: 'prediction_updates') this.predictionUpdates = true,
    @JsonKey(name: 'reward_updates') this.rewardUpdates = true,
    @JsonKey(name: 'marketing') this.marketing = false,
  });

  factory _$NotificationPreferencesImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationPreferencesImplFromJson(json);

  @override
  @JsonKey(name: 'goal_alerts')
  final bool goalAlerts;
  @override
  @JsonKey(name: 'prediction_updates')
  final bool predictionUpdates;
  @override
  @JsonKey(name: 'reward_updates')
  final bool rewardUpdates;
  @override
  @JsonKey(name: 'marketing')
  final bool marketing;

  @override
  String toString() {
    return 'NotificationPreferences(goalAlerts: $goalAlerts, predictionUpdates: $predictionUpdates, rewardUpdates: $rewardUpdates, marketing: $marketing)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationPreferencesImpl &&
            (identical(other.goalAlerts, goalAlerts) ||
                other.goalAlerts == goalAlerts) &&
            (identical(other.predictionUpdates, predictionUpdates) ||
                other.predictionUpdates == predictionUpdates) &&
            (identical(other.rewardUpdates, rewardUpdates) ||
                other.rewardUpdates == rewardUpdates) &&
            (identical(other.marketing, marketing) ||
                other.marketing == marketing));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    goalAlerts,
    predictionUpdates,
    rewardUpdates,
    marketing,
  );

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationPreferencesImplCopyWith<_$NotificationPreferencesImpl>
  get copyWith =>
      __$$NotificationPreferencesImplCopyWithImpl<
        _$NotificationPreferencesImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationPreferencesImplToJson(this);
  }
}

abstract class _NotificationPreferences implements NotificationPreferences {
  const factory _NotificationPreferences({
    @JsonKey(name: 'goal_alerts') final bool goalAlerts,
    @JsonKey(name: 'prediction_updates') final bool predictionUpdates,
    @JsonKey(name: 'reward_updates') final bool rewardUpdates,
    @JsonKey(name: 'marketing') final bool marketing,
  }) = _$NotificationPreferencesImpl;

  factory _NotificationPreferences.fromJson(Map<String, dynamic> json) =
      _$NotificationPreferencesImpl.fromJson;

  @override
  @JsonKey(name: 'goal_alerts')
  bool get goalAlerts;
  @override
  @JsonKey(name: 'prediction_updates')
  bool get predictionUpdates;
  @override
  @JsonKey(name: 'reward_updates')
  bool get rewardUpdates;
  @override
  @JsonKey(name: 'marketing')
  bool get marketing;

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationPreferencesImplCopyWith<_$NotificationPreferencesImpl>
  get copyWith => throw _privateConstructorUsedError;
}

UserStats _$UserStatsFromJson(Map<String, dynamic> json) {
  return _UserStats.fromJson(json);
}

/// @nodoc
mixin _$UserStats {
  @JsonKey(name: 'prediction_streak')
  int get predictionStreak => throw _privateConstructorUsedError;
  @JsonKey(name: 'longest_streak')
  int get longestStreak => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_predictions')
  int get totalPredictions => throw _privateConstructorUsedError;
  @JsonKey(name: 'correct_predictions')
  int get correctPredictions => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_fet_earned')
  int get totalFetEarned => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_fet_spent')
  int get totalFetSpent => throw _privateConstructorUsedError;

  /// Serializes this UserStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserStatsCopyWith<UserStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserStatsCopyWith<$Res> {
  factory $UserStatsCopyWith(UserStats value, $Res Function(UserStats) then) =
      _$UserStatsCopyWithImpl<$Res, UserStats>;
  @useResult
  $Res call({
    @JsonKey(name: 'prediction_streak') int predictionStreak,
    @JsonKey(name: 'longest_streak') int longestStreak,
    @JsonKey(name: 'total_predictions') int totalPredictions,
    @JsonKey(name: 'correct_predictions') int correctPredictions,
    @JsonKey(name: 'total_fet_earned') int totalFetEarned,
    @JsonKey(name: 'total_fet_spent') int totalFetSpent,
  });
}

/// @nodoc
class _$UserStatsCopyWithImpl<$Res, $Val extends UserStats>
    implements $UserStatsCopyWith<$Res> {
  _$UserStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? predictionStreak = null,
    Object? longestStreak = null,
    Object? totalPredictions = null,
    Object? correctPredictions = null,
    Object? totalFetEarned = null,
    Object? totalFetSpent = null,
  }) {
    return _then(
      _value.copyWith(
            predictionStreak: null == predictionStreak
                ? _value.predictionStreak
                : predictionStreak // ignore: cast_nullable_to_non_nullable
                      as int,
            longestStreak: null == longestStreak
                ? _value.longestStreak
                : longestStreak // ignore: cast_nullable_to_non_nullable
                      as int,
            totalPredictions: null == totalPredictions
                ? _value.totalPredictions
                : totalPredictions // ignore: cast_nullable_to_non_nullable
                      as int,
            correctPredictions: null == correctPredictions
                ? _value.correctPredictions
                : correctPredictions // ignore: cast_nullable_to_non_nullable
                      as int,
            totalFetEarned: null == totalFetEarned
                ? _value.totalFetEarned
                : totalFetEarned // ignore: cast_nullable_to_non_nullable
                      as int,
            totalFetSpent: null == totalFetSpent
                ? _value.totalFetSpent
                : totalFetSpent // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserStatsImplCopyWith<$Res>
    implements $UserStatsCopyWith<$Res> {
  factory _$$UserStatsImplCopyWith(
    _$UserStatsImpl value,
    $Res Function(_$UserStatsImpl) then,
  ) = __$$UserStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'prediction_streak') int predictionStreak,
    @JsonKey(name: 'longest_streak') int longestStreak,
    @JsonKey(name: 'total_predictions') int totalPredictions,
    @JsonKey(name: 'correct_predictions') int correctPredictions,
    @JsonKey(name: 'total_fet_earned') int totalFetEarned,
    @JsonKey(name: 'total_fet_spent') int totalFetSpent,
  });
}

/// @nodoc
class __$$UserStatsImplCopyWithImpl<$Res>
    extends _$UserStatsCopyWithImpl<$Res, _$UserStatsImpl>
    implements _$$UserStatsImplCopyWith<$Res> {
  __$$UserStatsImplCopyWithImpl(
    _$UserStatsImpl _value,
    $Res Function(_$UserStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? predictionStreak = null,
    Object? longestStreak = null,
    Object? totalPredictions = null,
    Object? correctPredictions = null,
    Object? totalFetEarned = null,
    Object? totalFetSpent = null,
  }) {
    return _then(
      _$UserStatsImpl(
        predictionStreak: null == predictionStreak
            ? _value.predictionStreak
            : predictionStreak // ignore: cast_nullable_to_non_nullable
                  as int,
        longestStreak: null == longestStreak
            ? _value.longestStreak
            : longestStreak // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPredictions: null == totalPredictions
            ? _value.totalPredictions
            : totalPredictions // ignore: cast_nullable_to_non_nullable
                  as int,
        correctPredictions: null == correctPredictions
            ? _value.correctPredictions
            : correctPredictions // ignore: cast_nullable_to_non_nullable
                  as int,
        totalFetEarned: null == totalFetEarned
            ? _value.totalFetEarned
            : totalFetEarned // ignore: cast_nullable_to_non_nullable
                  as int,
        totalFetSpent: null == totalFetSpent
            ? _value.totalFetSpent
            : totalFetSpent // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserStatsImpl implements _UserStats {
  const _$UserStatsImpl({
    @JsonKey(name: 'prediction_streak') this.predictionStreak = 0,
    @JsonKey(name: 'longest_streak') this.longestStreak = 0,
    @JsonKey(name: 'total_predictions') this.totalPredictions = 0,
    @JsonKey(name: 'correct_predictions') this.correctPredictions = 0,
    @JsonKey(name: 'total_fet_earned') this.totalFetEarned = 0,
    @JsonKey(name: 'total_fet_spent') this.totalFetSpent = 0,
  });

  factory _$UserStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserStatsImplFromJson(json);

  @override
  @JsonKey(name: 'prediction_streak')
  final int predictionStreak;
  @override
  @JsonKey(name: 'longest_streak')
  final int longestStreak;
  @override
  @JsonKey(name: 'total_predictions')
  final int totalPredictions;
  @override
  @JsonKey(name: 'correct_predictions')
  final int correctPredictions;
  @override
  @JsonKey(name: 'total_fet_earned')
  final int totalFetEarned;
  @override
  @JsonKey(name: 'total_fet_spent')
  final int totalFetSpent;

  @override
  String toString() {
    return 'UserStats(predictionStreak: $predictionStreak, longestStreak: $longestStreak, totalPredictions: $totalPredictions, correctPredictions: $correctPredictions, totalFetEarned: $totalFetEarned, totalFetSpent: $totalFetSpent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserStatsImpl &&
            (identical(other.predictionStreak, predictionStreak) ||
                other.predictionStreak == predictionStreak) &&
            (identical(other.longestStreak, longestStreak) ||
                other.longestStreak == longestStreak) &&
            (identical(other.totalPredictions, totalPredictions) ||
                other.totalPredictions == totalPredictions) &&
            (identical(other.correctPredictions, correctPredictions) ||
                other.correctPredictions == correctPredictions) &&
            (identical(other.totalFetEarned, totalFetEarned) ||
                other.totalFetEarned == totalFetEarned) &&
            (identical(other.totalFetSpent, totalFetSpent) ||
                other.totalFetSpent == totalFetSpent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    predictionStreak,
    longestStreak,
    totalPredictions,
    correctPredictions,
    totalFetEarned,
    totalFetSpent,
  );

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserStatsImplCopyWith<_$UserStatsImpl> get copyWith =>
      __$$UserStatsImplCopyWithImpl<_$UserStatsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserStatsImplToJson(this);
  }
}

abstract class _UserStats implements UserStats {
  const factory _UserStats({
    @JsonKey(name: 'prediction_streak') final int predictionStreak,
    @JsonKey(name: 'longest_streak') final int longestStreak,
    @JsonKey(name: 'total_predictions') final int totalPredictions,
    @JsonKey(name: 'correct_predictions') final int correctPredictions,
    @JsonKey(name: 'total_fet_earned') final int totalFetEarned,
    @JsonKey(name: 'total_fet_spent') final int totalFetSpent,
  }) = _$UserStatsImpl;

  factory _UserStats.fromJson(Map<String, dynamic> json) =
      _$UserStatsImpl.fromJson;

  @override
  @JsonKey(name: 'prediction_streak')
  int get predictionStreak;
  @override
  @JsonKey(name: 'longest_streak')
  int get longestStreak;
  @override
  @JsonKey(name: 'total_predictions')
  int get totalPredictions;
  @override
  @JsonKey(name: 'correct_predictions')
  int get correctPredictions;
  @override
  @JsonKey(name: 'total_fet_earned')
  int get totalFetEarned;
  @override
  @JsonKey(name: 'total_fet_spent')
  int get totalFetSpent;

  /// Create a copy of UserStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserStatsImplCopyWith<_$UserStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
