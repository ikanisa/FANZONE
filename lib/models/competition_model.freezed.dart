// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'competition_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CompetitionModel _$CompetitionModelFromJson(Map<String, dynamic> json) {
  return _CompetitionModel.fromJson(json);
}

/// @nodoc
mixin _$CompetitionModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'short_name')
  String get shortName => throw _privateConstructorUsedError;
  String get country => throw _privateConstructorUsedError;
  int get tier => throw _privateConstructorUsedError;
  @JsonKey(name: 'competition_type')
  String? get competitionType => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_featured')
  bool get isFeatured => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_international')
  bool get isInternational => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_season_id')
  String? get currentSeasonId => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_season_label')
  String? get currentSeasonLabel => throw _privateConstructorUsedError;
  @JsonKey(name: 'future_match_count')
  int get futureMatchCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'catalog_rank')
  int? get catalogRank => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this CompetitionModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CompetitionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CompetitionModelCopyWith<CompetitionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CompetitionModelCopyWith<$Res> {
  factory $CompetitionModelCopyWith(
    CompetitionModel value,
    $Res Function(CompetitionModel) then,
  ) = _$CompetitionModelCopyWithImpl<$Res, CompetitionModel>;
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'short_name') String shortName,
    String country,
    int tier,
    @JsonKey(name: 'competition_type') String? competitionType,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'is_international') bool isInternational,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'current_season_id') String? currentSeasonId,
    @JsonKey(name: 'current_season_label') String? currentSeasonLabel,
    @JsonKey(name: 'future_match_count') int futureMatchCount,
    @JsonKey(name: 'catalog_rank') int? catalogRank,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class _$CompetitionModelCopyWithImpl<$Res, $Val extends CompetitionModel>
    implements $CompetitionModelCopyWith<$Res> {
  _$CompetitionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CompetitionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? shortName = null,
    Object? country = null,
    Object? tier = null,
    Object? competitionType = freezed,
    Object? isFeatured = null,
    Object? isInternational = null,
    Object? isActive = null,
    Object? currentSeasonId = freezed,
    Object? currentSeasonLabel = freezed,
    Object? futureMatchCount = null,
    Object? catalogRank = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
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
            country: null == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String,
            tier: null == tier
                ? _value.tier
                : tier // ignore: cast_nullable_to_non_nullable
                      as int,
            competitionType: freezed == competitionType
                ? _value.competitionType
                : competitionType // ignore: cast_nullable_to_non_nullable
                      as String?,
            isFeatured: null == isFeatured
                ? _value.isFeatured
                : isFeatured // ignore: cast_nullable_to_non_nullable
                      as bool,
            isInternational: null == isInternational
                ? _value.isInternational
                : isInternational // ignore: cast_nullable_to_non_nullable
                      as bool,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            currentSeasonId: freezed == currentSeasonId
                ? _value.currentSeasonId
                : currentSeasonId // ignore: cast_nullable_to_non_nullable
                      as String?,
            currentSeasonLabel: freezed == currentSeasonLabel
                ? _value.currentSeasonLabel
                : currentSeasonLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
            futureMatchCount: null == futureMatchCount
                ? _value.futureMatchCount
                : futureMatchCount // ignore: cast_nullable_to_non_nullable
                      as int,
            catalogRank: freezed == catalogRank
                ? _value.catalogRank
                : catalogRank // ignore: cast_nullable_to_non_nullable
                      as int?,
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
abstract class _$$CompetitionModelImplCopyWith<$Res>
    implements $CompetitionModelCopyWith<$Res> {
  factory _$$CompetitionModelImplCopyWith(
    _$CompetitionModelImpl value,
    $Res Function(_$CompetitionModelImpl) then,
  ) = __$$CompetitionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'short_name') String shortName,
    String country,
    int tier,
    @JsonKey(name: 'competition_type') String? competitionType,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'is_international') bool isInternational,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'current_season_id') String? currentSeasonId,
    @JsonKey(name: 'current_season_label') String? currentSeasonLabel,
    @JsonKey(name: 'future_match_count') int futureMatchCount,
    @JsonKey(name: 'catalog_rank') int? catalogRank,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class __$$CompetitionModelImplCopyWithImpl<$Res>
    extends _$CompetitionModelCopyWithImpl<$Res, _$CompetitionModelImpl>
    implements _$$CompetitionModelImplCopyWith<$Res> {
  __$$CompetitionModelImplCopyWithImpl(
    _$CompetitionModelImpl _value,
    $Res Function(_$CompetitionModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CompetitionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? shortName = null,
    Object? country = null,
    Object? tier = null,
    Object? competitionType = freezed,
    Object? isFeatured = null,
    Object? isInternational = null,
    Object? isActive = null,
    Object? currentSeasonId = freezed,
    Object? currentSeasonLabel = freezed,
    Object? futureMatchCount = null,
    Object? catalogRank = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$CompetitionModelImpl(
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
        country: null == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String,
        tier: null == tier
            ? _value.tier
            : tier // ignore: cast_nullable_to_non_nullable
                  as int,
        competitionType: freezed == competitionType
            ? _value.competitionType
            : competitionType // ignore: cast_nullable_to_non_nullable
                  as String?,
        isFeatured: null == isFeatured
            ? _value.isFeatured
            : isFeatured // ignore: cast_nullable_to_non_nullable
                  as bool,
        isInternational: null == isInternational
            ? _value.isInternational
            : isInternational // ignore: cast_nullable_to_non_nullable
                  as bool,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        currentSeasonId: freezed == currentSeasonId
            ? _value.currentSeasonId
            : currentSeasonId // ignore: cast_nullable_to_non_nullable
                  as String?,
        currentSeasonLabel: freezed == currentSeasonLabel
            ? _value.currentSeasonLabel
            : currentSeasonLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        futureMatchCount: null == futureMatchCount
            ? _value.futureMatchCount
            : futureMatchCount // ignore: cast_nullable_to_non_nullable
                  as int,
        catalogRank: freezed == catalogRank
            ? _value.catalogRank
            : catalogRank // ignore: cast_nullable_to_non_nullable
                  as int?,
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
class _$CompetitionModelImpl extends _CompetitionModel {
  const _$CompetitionModelImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'short_name') this.shortName = '',
    this.country = '',
    this.tier = 1,
    @JsonKey(name: 'competition_type') this.competitionType,
    @JsonKey(name: 'is_featured') this.isFeatured = false,
    @JsonKey(name: 'is_international') this.isInternational = false,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'current_season_id') this.currentSeasonId,
    @JsonKey(name: 'current_season_label') this.currentSeasonLabel,
    @JsonKey(name: 'future_match_count') this.futureMatchCount = 0,
    @JsonKey(name: 'catalog_rank') this.catalogRank,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  }) : super._();

  factory _$CompetitionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$CompetitionModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'short_name')
  final String shortName;
  @override
  @JsonKey()
  final String country;
  @override
  @JsonKey()
  final int tier;
  @override
  @JsonKey(name: 'competition_type')
  final String? competitionType;
  @override
  @JsonKey(name: 'is_featured')
  final bool isFeatured;
  @override
  @JsonKey(name: 'is_international')
  final bool isInternational;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'current_season_id')
  final String? currentSeasonId;
  @override
  @JsonKey(name: 'current_season_label')
  final String? currentSeasonLabel;
  @override
  @JsonKey(name: 'future_match_count')
  final int futureMatchCount;
  @override
  @JsonKey(name: 'catalog_rank')
  final int? catalogRank;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'CompetitionModel(id: $id, name: $name, shortName: $shortName, country: $country, tier: $tier, competitionType: $competitionType, isFeatured: $isFeatured, isInternational: $isInternational, isActive: $isActive, currentSeasonId: $currentSeasonId, currentSeasonLabel: $currentSeasonLabel, futureMatchCount: $futureMatchCount, catalogRank: $catalogRank, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CompetitionModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.shortName, shortName) ||
                other.shortName == shortName) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.competitionType, competitionType) ||
                other.competitionType == competitionType) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.isInternational, isInternational) ||
                other.isInternational == isInternational) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.currentSeasonId, currentSeasonId) ||
                other.currentSeasonId == currentSeasonId) &&
            (identical(other.currentSeasonLabel, currentSeasonLabel) ||
                other.currentSeasonLabel == currentSeasonLabel) &&
            (identical(other.futureMatchCount, futureMatchCount) ||
                other.futureMatchCount == futureMatchCount) &&
            (identical(other.catalogRank, catalogRank) ||
                other.catalogRank == catalogRank) &&
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
    name,
    shortName,
    country,
    tier,
    competitionType,
    isFeatured,
    isInternational,
    isActive,
    currentSeasonId,
    currentSeasonLabel,
    futureMatchCount,
    catalogRank,
    createdAt,
    updatedAt,
  );

  /// Create a copy of CompetitionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CompetitionModelImplCopyWith<_$CompetitionModelImpl> get copyWith =>
      __$$CompetitionModelImplCopyWithImpl<_$CompetitionModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CompetitionModelImplToJson(this);
  }
}

abstract class _CompetitionModel extends CompetitionModel {
  const factory _CompetitionModel({
    required final String id,
    required final String name,
    @JsonKey(name: 'short_name') final String shortName,
    final String country,
    final int tier,
    @JsonKey(name: 'competition_type') final String? competitionType,
    @JsonKey(name: 'is_featured') final bool isFeatured,
    @JsonKey(name: 'is_international') final bool isInternational,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'current_season_id') final String? currentSeasonId,
    @JsonKey(name: 'current_season_label') final String? currentSeasonLabel,
    @JsonKey(name: 'future_match_count') final int futureMatchCount,
    @JsonKey(name: 'catalog_rank') final int? catalogRank,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$CompetitionModelImpl;
  const _CompetitionModel._() : super._();

  factory _CompetitionModel.fromJson(Map<String, dynamic> json) =
      _$CompetitionModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'short_name')
  String get shortName;
  @override
  String get country;
  @override
  int get tier;
  @override
  @JsonKey(name: 'competition_type')
  String? get competitionType;
  @override
  @JsonKey(name: 'is_featured')
  bool get isFeatured;
  @override
  @JsonKey(name: 'is_international')
  bool get isInternational;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'current_season_id')
  String? get currentSeasonId;
  @override
  @JsonKey(name: 'current_season_label')
  String? get currentSeasonLabel;
  @override
  @JsonKey(name: 'future_match_count')
  int get futureMatchCount;
  @override
  @JsonKey(name: 'catalog_rank')
  int? get catalogRank;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of CompetitionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CompetitionModelImplCopyWith<_$CompetitionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
