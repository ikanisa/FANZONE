// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'featured_event_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FeaturedEventModel _$FeaturedEventModelFromJson(Map<String, dynamic> json) {
  return _FeaturedEventModel.fromJson(json);
}

/// @nodoc
mixin _$FeaturedEventModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'short_name')
  String get shortName => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_tag')
  String get eventTag => throw _privateConstructorUsedError;

  /// global, africa, europe, americas
  String get region => throw _privateConstructorUsedError;
  @JsonKey(name: 'competition_id')
  String? get competitionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_date')
  DateTime get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  DateTime get endDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'banner_color')
  String? get bannerColor => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String? get logoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this FeaturedEventModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeaturedEventModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeaturedEventModelCopyWith<FeaturedEventModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeaturedEventModelCopyWith<$Res> {
  factory $FeaturedEventModelCopyWith(
    FeaturedEventModel value,
    $Res Function(FeaturedEventModel) then,
  ) = _$FeaturedEventModelCopyWithImpl<$Res, FeaturedEventModel>;
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'short_name') String shortName,
    @JsonKey(name: 'event_tag') String eventTag,
    String region,
    @JsonKey(name: 'competition_id') String? competitionId,
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime endDate,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'banner_color') String? bannerColor,
    String? description,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$FeaturedEventModelCopyWithImpl<$Res, $Val extends FeaturedEventModel>
    implements $FeaturedEventModelCopyWith<$Res> {
  _$FeaturedEventModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeaturedEventModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? shortName = null,
    Object? eventTag = null,
    Object? region = null,
    Object? competitionId = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? isActive = null,
    Object? bannerColor = freezed,
    Object? description = freezed,
    Object? logoUrl = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            shortName: null == shortName
                ? _value.shortName
                : shortName // ignore: cast_nullable_to_non_nullable
                      as String,
            eventTag: null == eventTag
                ? _value.eventTag
                : eventTag // ignore: cast_nullable_to_non_nullable
                      as String,
            region: null == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as String,
            competitionId: freezed == competitionId
                ? _value.competitionId
                : competitionId // ignore: cast_nullable_to_non_nullable
                      as String?,
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: null == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            bannerColor: freezed == bannerColor
                ? _value.bannerColor
                : bannerColor // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            logoUrl: freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
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
abstract class _$$FeaturedEventModelImplCopyWith<$Res>
    implements $FeaturedEventModelCopyWith<$Res> {
  factory _$$FeaturedEventModelImplCopyWith(
    _$FeaturedEventModelImpl value,
    $Res Function(_$FeaturedEventModelImpl) then,
  ) = __$$FeaturedEventModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'short_name') String shortName,
    @JsonKey(name: 'event_tag') String eventTag,
    String region,
    @JsonKey(name: 'competition_id') String? competitionId,
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime endDate,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'banner_color') String? bannerColor,
    String? description,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$FeaturedEventModelImplCopyWithImpl<$Res>
    extends _$FeaturedEventModelCopyWithImpl<$Res, _$FeaturedEventModelImpl>
    implements _$$FeaturedEventModelImplCopyWith<$Res> {
  __$$FeaturedEventModelImplCopyWithImpl(
    _$FeaturedEventModelImpl _value,
    $Res Function(_$FeaturedEventModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeaturedEventModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? shortName = null,
    Object? eventTag = null,
    Object? region = null,
    Object? competitionId = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? isActive = null,
    Object? bannerColor = freezed,
    Object? description = freezed,
    Object? logoUrl = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$FeaturedEventModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        shortName: null == shortName
            ? _value.shortName
            : shortName // ignore: cast_nullable_to_non_nullable
                  as String,
        eventTag: null == eventTag
            ? _value.eventTag
            : eventTag // ignore: cast_nullable_to_non_nullable
                  as String,
        region: null == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as String,
        competitionId: freezed == competitionId
            ? _value.competitionId
            : competitionId // ignore: cast_nullable_to_non_nullable
                  as String?,
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: null == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        bannerColor: freezed == bannerColor
            ? _value.bannerColor
            : bannerColor // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        logoUrl: freezed == logoUrl
            ? _value.logoUrl
            : logoUrl // ignore: cast_nullable_to_non_nullable
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
class _$FeaturedEventModelImpl extends _FeaturedEventModel {
  const _$FeaturedEventModelImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'short_name') required this.shortName,
    @JsonKey(name: 'event_tag') required this.eventTag,
    this.region = 'global',
    @JsonKey(name: 'competition_id') this.competitionId,
    @JsonKey(name: 'start_date') required this.startDate,
    @JsonKey(name: 'end_date') required this.endDate,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'banner_color') this.bannerColor,
    this.description,
    @JsonKey(name: 'logo_url') this.logoUrl,
    @JsonKey(name: 'created_at') this.createdAt,
  }) : super._();

  factory _$FeaturedEventModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeaturedEventModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'short_name')
  final String shortName;
  @override
  @JsonKey(name: 'event_tag')
  final String eventTag;

  /// global, africa, europe, americas
  @override
  @JsonKey()
  final String region;
  @override
  @JsonKey(name: 'competition_id')
  final String? competitionId;
  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime endDate;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'banner_color')
  final String? bannerColor;
  @override
  final String? description;
  @override
  @JsonKey(name: 'logo_url')
  final String? logoUrl;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'FeaturedEventModel(id: $id, name: $name, shortName: $shortName, eventTag: $eventTag, region: $region, competitionId: $competitionId, startDate: $startDate, endDate: $endDate, isActive: $isActive, bannerColor: $bannerColor, description: $description, logoUrl: $logoUrl, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeaturedEventModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.shortName, shortName) ||
                other.shortName == shortName) &&
            (identical(other.eventTag, eventTag) ||
                other.eventTag == eventTag) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.competitionId, competitionId) ||
                other.competitionId == competitionId) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.bannerColor, bannerColor) ||
                other.bannerColor == bannerColor) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    shortName,
    eventTag,
    region,
    competitionId,
    startDate,
    endDate,
    isActive,
    bannerColor,
    description,
    logoUrl,
    createdAt,
  );

  /// Create a copy of FeaturedEventModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeaturedEventModelImplCopyWith<_$FeaturedEventModelImpl> get copyWith =>
      __$$FeaturedEventModelImplCopyWithImpl<_$FeaturedEventModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FeaturedEventModelImplToJson(this);
  }
}

abstract class _FeaturedEventModel extends FeaturedEventModel {
  const factory _FeaturedEventModel({
    required final String id,
    required final String name,
    @JsonKey(name: 'short_name') required final String shortName,
    @JsonKey(name: 'event_tag') required final String eventTag,
    final String region,
    @JsonKey(name: 'competition_id') final String? competitionId,
    @JsonKey(name: 'start_date') required final DateTime startDate,
    @JsonKey(name: 'end_date') required final DateTime endDate,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'banner_color') final String? bannerColor,
    final String? description,
    @JsonKey(name: 'logo_url') final String? logoUrl,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$FeaturedEventModelImpl;
  const _FeaturedEventModel._() : super._();

  factory _FeaturedEventModel.fromJson(Map<String, dynamic> json) =
      _$FeaturedEventModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'short_name')
  String get shortName;
  @override
  @JsonKey(name: 'event_tag')
  String get eventTag;

  /// global, africa, europe, americas
  @override
  String get region;
  @override
  @JsonKey(name: 'competition_id')
  String? get competitionId;
  @override
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @override
  @JsonKey(name: 'end_date')
  DateTime get endDate;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'banner_color')
  String? get bannerColor;
  @override
  String? get description;
  @override
  @JsonKey(name: 'logo_url')
  String? get logoUrl;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of FeaturedEventModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeaturedEventModelImplCopyWith<_$FeaturedEventModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
