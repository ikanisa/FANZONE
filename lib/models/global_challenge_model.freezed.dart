// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'global_challenge_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GlobalChallengeModel _$GlobalChallengeModelFromJson(Map<String, dynamic> json) {
  return _GlobalChallengeModel.fromJson(json);
}

/// @nodoc
mixin _$GlobalChallengeModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_tag')
  String get eventTag => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'match_ids')
  List<String> get matchIds => throw _privateConstructorUsedError;
  @JsonKey(name: 'entry_fee_fet')
  int get entryFeeFet => throw _privateConstructorUsedError;
  @JsonKey(name: 'prize_pool_fet')
  int get prizePoolFet => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_participants')
  int? get maxParticipants => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_participants')
  int get currentParticipants => throw _privateConstructorUsedError;

  /// global, africa, europe, americas
  String get region => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_at')
  DateTime? get startAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_at')
  DateTime? get endAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this GlobalChallengeModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GlobalChallengeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlobalChallengeModelCopyWith<GlobalChallengeModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlobalChallengeModelCopyWith<$Res> {
  factory $GlobalChallengeModelCopyWith(
    GlobalChallengeModel value,
    $Res Function(GlobalChallengeModel) then,
  ) = _$GlobalChallengeModelCopyWithImpl<$Res, GlobalChallengeModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'event_tag') String eventTag,
    String name,
    String? description,
    @JsonKey(name: 'match_ids') List<String> matchIds,
    @JsonKey(name: 'entry_fee_fet') int entryFeeFet,
    @JsonKey(name: 'prize_pool_fet') int prizePoolFet,
    @JsonKey(name: 'max_participants') int? maxParticipants,
    @JsonKey(name: 'current_participants') int currentParticipants,
    String region,
    String status,
    @JsonKey(name: 'start_at') DateTime? startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$GlobalChallengeModelCopyWithImpl<
  $Res,
  $Val extends GlobalChallengeModel
>
    implements $GlobalChallengeModelCopyWith<$Res> {
  _$GlobalChallengeModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlobalChallengeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? eventTag = null,
    Object? name = null,
    Object? description = freezed,
    Object? matchIds = null,
    Object? entryFeeFet = null,
    Object? prizePoolFet = null,
    Object? maxParticipants = freezed,
    Object? currentParticipants = null,
    Object? region = null,
    Object? status = null,
    Object? startAt = freezed,
    Object? endAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            eventTag: null == eventTag
                ? _value.eventTag
                : eventTag // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            matchIds: null == matchIds
                ? _value.matchIds
                : matchIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            entryFeeFet: null == entryFeeFet
                ? _value.entryFeeFet
                : entryFeeFet // ignore: cast_nullable_to_non_nullable
                      as int,
            prizePoolFet: null == prizePoolFet
                ? _value.prizePoolFet
                : prizePoolFet // ignore: cast_nullable_to_non_nullable
                      as int,
            maxParticipants: freezed == maxParticipants
                ? _value.maxParticipants
                : maxParticipants // ignore: cast_nullable_to_non_nullable
                      as int?,
            currentParticipants: null == currentParticipants
                ? _value.currentParticipants
                : currentParticipants // ignore: cast_nullable_to_non_nullable
                      as int,
            region: null == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            startAt: freezed == startAt
                ? _value.startAt
                : startAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endAt: freezed == endAt
                ? _value.endAt
                : endAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
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
abstract class _$$GlobalChallengeModelImplCopyWith<$Res>
    implements $GlobalChallengeModelCopyWith<$Res> {
  factory _$$GlobalChallengeModelImplCopyWith(
    _$GlobalChallengeModelImpl value,
    $Res Function(_$GlobalChallengeModelImpl) then,
  ) = __$$GlobalChallengeModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'event_tag') String eventTag,
    String name,
    String? description,
    @JsonKey(name: 'match_ids') List<String> matchIds,
    @JsonKey(name: 'entry_fee_fet') int entryFeeFet,
    @JsonKey(name: 'prize_pool_fet') int prizePoolFet,
    @JsonKey(name: 'max_participants') int? maxParticipants,
    @JsonKey(name: 'current_participants') int currentParticipants,
    String region,
    String status,
    @JsonKey(name: 'start_at') DateTime? startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$GlobalChallengeModelImplCopyWithImpl<$Res>
    extends _$GlobalChallengeModelCopyWithImpl<$Res, _$GlobalChallengeModelImpl>
    implements _$$GlobalChallengeModelImplCopyWith<$Res> {
  __$$GlobalChallengeModelImplCopyWithImpl(
    _$GlobalChallengeModelImpl _value,
    $Res Function(_$GlobalChallengeModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlobalChallengeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? eventTag = null,
    Object? name = null,
    Object? description = freezed,
    Object? matchIds = null,
    Object? entryFeeFet = null,
    Object? prizePoolFet = null,
    Object? maxParticipants = freezed,
    Object? currentParticipants = null,
    Object? region = null,
    Object? status = null,
    Object? startAt = freezed,
    Object? endAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$GlobalChallengeModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        eventTag: null == eventTag
            ? _value.eventTag
            : eventTag // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        matchIds: null == matchIds
            ? _value._matchIds
            : matchIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        entryFeeFet: null == entryFeeFet
            ? _value.entryFeeFet
            : entryFeeFet // ignore: cast_nullable_to_non_nullable
                  as int,
        prizePoolFet: null == prizePoolFet
            ? _value.prizePoolFet
            : prizePoolFet // ignore: cast_nullable_to_non_nullable
                  as int,
        maxParticipants: freezed == maxParticipants
            ? _value.maxParticipants
            : maxParticipants // ignore: cast_nullable_to_non_nullable
                  as int?,
        currentParticipants: null == currentParticipants
            ? _value.currentParticipants
            : currentParticipants // ignore: cast_nullable_to_non_nullable
                  as int,
        region: null == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        startAt: freezed == startAt
            ? _value.startAt
            : startAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endAt: freezed == endAt
            ? _value.endAt
            : endAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
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
class _$GlobalChallengeModelImpl extends _GlobalChallengeModel {
  const _$GlobalChallengeModelImpl({
    required this.id,
    @JsonKey(name: 'event_tag') required this.eventTag,
    required this.name,
    this.description,
    @JsonKey(name: 'match_ids') final List<String> matchIds = const [],
    @JsonKey(name: 'entry_fee_fet') this.entryFeeFet = 0,
    @JsonKey(name: 'prize_pool_fet') this.prizePoolFet = 0,
    @JsonKey(name: 'max_participants') this.maxParticipants,
    @JsonKey(name: 'current_participants') this.currentParticipants = 0,
    this.region = 'global',
    this.status = 'open',
    @JsonKey(name: 'start_at') this.startAt,
    @JsonKey(name: 'end_at') this.endAt,
    @JsonKey(name: 'created_at') this.createdAt,
  }) : _matchIds = matchIds,
       super._();

  factory _$GlobalChallengeModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GlobalChallengeModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'event_tag')
  final String eventTag;
  @override
  final String name;
  @override
  final String? description;
  final List<String> _matchIds;
  @override
  @JsonKey(name: 'match_ids')
  List<String> get matchIds {
    if (_matchIds is EqualUnmodifiableListView) return _matchIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_matchIds);
  }

  @override
  @JsonKey(name: 'entry_fee_fet')
  final int entryFeeFet;
  @override
  @JsonKey(name: 'prize_pool_fet')
  final int prizePoolFet;
  @override
  @JsonKey(name: 'max_participants')
  final int? maxParticipants;
  @override
  @JsonKey(name: 'current_participants')
  final int currentParticipants;

  /// global, africa, europe, americas
  @override
  @JsonKey()
  final String region;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'start_at')
  final DateTime? startAt;
  @override
  @JsonKey(name: 'end_at')
  final DateTime? endAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'GlobalChallengeModel(id: $id, eventTag: $eventTag, name: $name, description: $description, matchIds: $matchIds, entryFeeFet: $entryFeeFet, prizePoolFet: $prizePoolFet, maxParticipants: $maxParticipants, currentParticipants: $currentParticipants, region: $region, status: $status, startAt: $startAt, endAt: $endAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GlobalChallengeModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.eventTag, eventTag) ||
                other.eventTag == eventTag) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._matchIds, _matchIds) &&
            (identical(other.entryFeeFet, entryFeeFet) ||
                other.entryFeeFet == entryFeeFet) &&
            (identical(other.prizePoolFet, prizePoolFet) ||
                other.prizePoolFet == prizePoolFet) &&
            (identical(other.maxParticipants, maxParticipants) ||
                other.maxParticipants == maxParticipants) &&
            (identical(other.currentParticipants, currentParticipants) ||
                other.currentParticipants == currentParticipants) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.startAt, startAt) || other.startAt == startAt) &&
            (identical(other.endAt, endAt) || other.endAt == endAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    eventTag,
    name,
    description,
    const DeepCollectionEquality().hash(_matchIds),
    entryFeeFet,
    prizePoolFet,
    maxParticipants,
    currentParticipants,
    region,
    status,
    startAt,
    endAt,
    createdAt,
  );

  /// Create a copy of GlobalChallengeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlobalChallengeModelImplCopyWith<_$GlobalChallengeModelImpl>
  get copyWith =>
      __$$GlobalChallengeModelImplCopyWithImpl<_$GlobalChallengeModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GlobalChallengeModelImplToJson(this);
  }
}

abstract class _GlobalChallengeModel extends GlobalChallengeModel {
  const factory _GlobalChallengeModel({
    required final String id,
    @JsonKey(name: 'event_tag') required final String eventTag,
    required final String name,
    final String? description,
    @JsonKey(name: 'match_ids') final List<String> matchIds,
    @JsonKey(name: 'entry_fee_fet') final int entryFeeFet,
    @JsonKey(name: 'prize_pool_fet') final int prizePoolFet,
    @JsonKey(name: 'max_participants') final int? maxParticipants,
    @JsonKey(name: 'current_participants') final int currentParticipants,
    final String region,
    final String status,
    @JsonKey(name: 'start_at') final DateTime? startAt,
    @JsonKey(name: 'end_at') final DateTime? endAt,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$GlobalChallengeModelImpl;
  const _GlobalChallengeModel._() : super._();

  factory _GlobalChallengeModel.fromJson(Map<String, dynamic> json) =
      _$GlobalChallengeModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'event_tag')
  String get eventTag;
  @override
  String get name;
  @override
  String? get description;
  @override
  @JsonKey(name: 'match_ids')
  List<String> get matchIds;
  @override
  @JsonKey(name: 'entry_fee_fet')
  int get entryFeeFet;
  @override
  @JsonKey(name: 'prize_pool_fet')
  int get prizePoolFet;
  @override
  @JsonKey(name: 'max_participants')
  int? get maxParticipants;
  @override
  @JsonKey(name: 'current_participants')
  int get currentParticipants;

  /// global, africa, europe, americas
  @override
  String get region;
  @override
  String get status;
  @override
  @JsonKey(name: 'start_at')
  DateTime? get startAt;
  @override
  @JsonKey(name: 'end_at')
  DateTime? get endAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of GlobalChallengeModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlobalChallengeModelImplCopyWith<_$GlobalChallengeModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
