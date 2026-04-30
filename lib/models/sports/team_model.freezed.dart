// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TeamModel _$TeamModelFromJson(Map<String, dynamic> json) {
  return _TeamModel.fromJson(json);
}

/// @nodoc
mixin _$TeamModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'short_name')
  String? get shortName => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  @JsonKey(name: 'country_code')
  String? get countryCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_type')
  String get teamType => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'league_name')
  String? get leagueName => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError;
  @JsonKey(name: 'competition_ids')
  List<String> get competitionIds => throw _privateConstructorUsedError;
  List<String> get aliases => throw _privateConstructorUsedError;
  @JsonKey(name: 'search_terms')
  List<String> get searchTerms => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String? get logoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'crest_url')
  String? get crestUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'cover_image_url')
  String? get coverImageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_featured')
  bool get isFeatured => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_popular_pick')
  bool get isPopularPick => throw _privateConstructorUsedError;
  @JsonKey(name: 'popular_pick_rank')
  int? get popularPickRank => throw _privateConstructorUsedError;
  @JsonKey(name: 'fan_count')
  int get fanCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this TeamModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeamModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamModelCopyWith<TeamModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamModelCopyWith<$Res> {
  factory $TeamModelCopyWith(TeamModel value, $Res Function(TeamModel) then) =
      _$TeamModelCopyWithImpl<$Res, TeamModel>;
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'short_name') String? shortName,
    String? country,
    @JsonKey(name: 'country_code') String? countryCode,
    @JsonKey(name: 'team_type') String teamType,
    String? description,
    @JsonKey(name: 'league_name') String? leagueName,
    String? region,
    @JsonKey(name: 'competition_ids') List<String> competitionIds,
    List<String> aliases,
    @JsonKey(name: 'search_terms') List<String> searchTerms,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'crest_url') String? crestUrl,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'is_popular_pick') bool isPopularPick,
    @JsonKey(name: 'popular_pick_rank') int? popularPickRank,
    @JsonKey(name: 'fan_count') int fanCount,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class _$TeamModelCopyWithImpl<$Res, $Val extends TeamModel>
    implements $TeamModelCopyWith<$Res> {
  _$TeamModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? shortName = freezed,
    Object? country = freezed,
    Object? countryCode = freezed,
    Object? teamType = null,
    Object? description = freezed,
    Object? leagueName = freezed,
    Object? region = freezed,
    Object? competitionIds = null,
    Object? aliases = null,
    Object? searchTerms = null,
    Object? logoUrl = freezed,
    Object? crestUrl = freezed,
    Object? coverImageUrl = freezed,
    Object? isActive = null,
    Object? isFeatured = null,
    Object? isPopularPick = null,
    Object? popularPickRank = freezed,
    Object? fanCount = null,
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
            shortName: freezed == shortName
                ? _value.shortName
                : shortName // ignore: cast_nullable_to_non_nullable
                      as String?,
            country: freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String?,
            countryCode: freezed == countryCode
                ? _value.countryCode
                : countryCode // ignore: cast_nullable_to_non_nullable
                      as String?,
            teamType: null == teamType
                ? _value.teamType
                : teamType // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            leagueName: freezed == leagueName
                ? _value.leagueName
                : leagueName // ignore: cast_nullable_to_non_nullable
                      as String?,
            region: freezed == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as String?,
            competitionIds: null == competitionIds
                ? _value.competitionIds
                : competitionIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            aliases: null == aliases
                ? _value.aliases
                : aliases // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            searchTerms: null == searchTerms
                ? _value.searchTerms
                : searchTerms // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            logoUrl: freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            crestUrl: freezed == crestUrl
                ? _value.crestUrl
                : crestUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverImageUrl: freezed == coverImageUrl
                ? _value.coverImageUrl
                : coverImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            isFeatured: null == isFeatured
                ? _value.isFeatured
                : isFeatured // ignore: cast_nullable_to_non_nullable
                      as bool,
            isPopularPick: null == isPopularPick
                ? _value.isPopularPick
                : isPopularPick // ignore: cast_nullable_to_non_nullable
                      as bool,
            popularPickRank: freezed == popularPickRank
                ? _value.popularPickRank
                : popularPickRank // ignore: cast_nullable_to_non_nullable
                      as int?,
            fanCount: null == fanCount
                ? _value.fanCount
                : fanCount // ignore: cast_nullable_to_non_nullable
                      as int,
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
abstract class _$$TeamModelImplCopyWith<$Res>
    implements $TeamModelCopyWith<$Res> {
  factory _$$TeamModelImplCopyWith(
    _$TeamModelImpl value,
    $Res Function(_$TeamModelImpl) then,
  ) = __$$TeamModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'short_name') String? shortName,
    String? country,
    @JsonKey(name: 'country_code') String? countryCode,
    @JsonKey(name: 'team_type') String teamType,
    String? description,
    @JsonKey(name: 'league_name') String? leagueName,
    String? region,
    @JsonKey(name: 'competition_ids') List<String> competitionIds,
    List<String> aliases,
    @JsonKey(name: 'search_terms') List<String> searchTerms,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'crest_url') String? crestUrl,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'is_popular_pick') bool isPopularPick,
    @JsonKey(name: 'popular_pick_rank') int? popularPickRank,
    @JsonKey(name: 'fan_count') int fanCount,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class __$$TeamModelImplCopyWithImpl<$Res>
    extends _$TeamModelCopyWithImpl<$Res, _$TeamModelImpl>
    implements _$$TeamModelImplCopyWith<$Res> {
  __$$TeamModelImplCopyWithImpl(
    _$TeamModelImpl _value,
    $Res Function(_$TeamModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? shortName = freezed,
    Object? country = freezed,
    Object? countryCode = freezed,
    Object? teamType = null,
    Object? description = freezed,
    Object? leagueName = freezed,
    Object? region = freezed,
    Object? competitionIds = null,
    Object? aliases = null,
    Object? searchTerms = null,
    Object? logoUrl = freezed,
    Object? crestUrl = freezed,
    Object? coverImageUrl = freezed,
    Object? isActive = null,
    Object? isFeatured = null,
    Object? isPopularPick = null,
    Object? popularPickRank = freezed,
    Object? fanCount = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$TeamModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        shortName: freezed == shortName
            ? _value.shortName
            : shortName // ignore: cast_nullable_to_non_nullable
                  as String?,
        country: freezed == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String?,
        countryCode: freezed == countryCode
            ? _value.countryCode
            : countryCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        teamType: null == teamType
            ? _value.teamType
            : teamType // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        leagueName: freezed == leagueName
            ? _value.leagueName
            : leagueName // ignore: cast_nullable_to_non_nullable
                  as String?,
        region: freezed == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as String?,
        competitionIds: null == competitionIds
            ? _value._competitionIds
            : competitionIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        aliases: null == aliases
            ? _value._aliases
            : aliases // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        searchTerms: null == searchTerms
            ? _value._searchTerms
            : searchTerms // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        logoUrl: freezed == logoUrl
            ? _value.logoUrl
            : logoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        crestUrl: freezed == crestUrl
            ? _value.crestUrl
            : crestUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverImageUrl: freezed == coverImageUrl
            ? _value.coverImageUrl
            : coverImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        isFeatured: null == isFeatured
            ? _value.isFeatured
            : isFeatured // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPopularPick: null == isPopularPick
            ? _value.isPopularPick
            : isPopularPick // ignore: cast_nullable_to_non_nullable
                  as bool,
        popularPickRank: freezed == popularPickRank
            ? _value.popularPickRank
            : popularPickRank // ignore: cast_nullable_to_non_nullable
                  as int?,
        fanCount: null == fanCount
            ? _value.fanCount
            : fanCount // ignore: cast_nullable_to_non_nullable
                  as int,
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
class _$TeamModelImpl implements _TeamModel {
  const _$TeamModelImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'short_name') this.shortName,
    this.country,
    @JsonKey(name: 'country_code') this.countryCode,
    @JsonKey(name: 'team_type') this.teamType = 'club',
    this.description,
    @JsonKey(name: 'league_name') this.leagueName,
    this.region,
    @JsonKey(name: 'competition_ids')
    final List<String> competitionIds = const [],
    final List<String> aliases = const [],
    @JsonKey(name: 'search_terms') final List<String> searchTerms = const [],
    @JsonKey(name: 'logo_url') this.logoUrl,
    @JsonKey(name: 'crest_url') this.crestUrl,
    @JsonKey(name: 'cover_image_url') this.coverImageUrl,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'is_featured') this.isFeatured = false,
    @JsonKey(name: 'is_popular_pick') this.isPopularPick = false,
    @JsonKey(name: 'popular_pick_rank') this.popularPickRank,
    @JsonKey(name: 'fan_count') this.fanCount = 0,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  }) : _competitionIds = competitionIds,
       _aliases = aliases,
       _searchTerms = searchTerms;

  factory _$TeamModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeamModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'short_name')
  final String? shortName;
  @override
  final String? country;
  @override
  @JsonKey(name: 'country_code')
  final String? countryCode;
  @override
  @JsonKey(name: 'team_type')
  final String teamType;
  @override
  final String? description;
  @override
  @JsonKey(name: 'league_name')
  final String? leagueName;
  @override
  final String? region;
  final List<String> _competitionIds;
  @override
  @JsonKey(name: 'competition_ids')
  List<String> get competitionIds {
    if (_competitionIds is EqualUnmodifiableListView) return _competitionIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_competitionIds);
  }

  final List<String> _aliases;
  @override
  @JsonKey()
  List<String> get aliases {
    if (_aliases is EqualUnmodifiableListView) return _aliases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_aliases);
  }

  final List<String> _searchTerms;
  @override
  @JsonKey(name: 'search_terms')
  List<String> get searchTerms {
    if (_searchTerms is EqualUnmodifiableListView) return _searchTerms;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_searchTerms);
  }

  @override
  @JsonKey(name: 'logo_url')
  final String? logoUrl;
  @override
  @JsonKey(name: 'crest_url')
  final String? crestUrl;
  @override
  @JsonKey(name: 'cover_image_url')
  final String? coverImageUrl;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'is_featured')
  final bool isFeatured;
  @override
  @JsonKey(name: 'is_popular_pick')
  final bool isPopularPick;
  @override
  @JsonKey(name: 'popular_pick_rank')
  final int? popularPickRank;
  @override
  @JsonKey(name: 'fan_count')
  final int fanCount;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'TeamModel(id: $id, name: $name, shortName: $shortName, country: $country, countryCode: $countryCode, teamType: $teamType, description: $description, leagueName: $leagueName, region: $region, competitionIds: $competitionIds, aliases: $aliases, searchTerms: $searchTerms, logoUrl: $logoUrl, crestUrl: $crestUrl, coverImageUrl: $coverImageUrl, isActive: $isActive, isFeatured: $isFeatured, isPopularPick: $isPopularPick, popularPickRank: $popularPickRank, fanCount: $fanCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.shortName, shortName) ||
                other.shortName == shortName) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.countryCode, countryCode) ||
                other.countryCode == countryCode) &&
            (identical(other.teamType, teamType) ||
                other.teamType == teamType) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.leagueName, leagueName) ||
                other.leagueName == leagueName) &&
            (identical(other.region, region) || other.region == region) &&
            const DeepCollectionEquality().equals(
              other._competitionIds,
              _competitionIds,
            ) &&
            const DeepCollectionEquality().equals(other._aliases, _aliases) &&
            const DeepCollectionEquality().equals(
              other._searchTerms,
              _searchTerms,
            ) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.crestUrl, crestUrl) ||
                other.crestUrl == crestUrl) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.isPopularPick, isPopularPick) ||
                other.isPopularPick == isPopularPick) &&
            (identical(other.popularPickRank, popularPickRank) ||
                other.popularPickRank == popularPickRank) &&
            (identical(other.fanCount, fanCount) ||
                other.fanCount == fanCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    name,
    shortName,
    country,
    countryCode,
    teamType,
    description,
    leagueName,
    region,
    const DeepCollectionEquality().hash(_competitionIds),
    const DeepCollectionEquality().hash(_aliases),
    const DeepCollectionEquality().hash(_searchTerms),
    logoUrl,
    crestUrl,
    coverImageUrl,
    isActive,
    isFeatured,
    isPopularPick,
    popularPickRank,
    fanCount,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of TeamModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamModelImplCopyWith<_$TeamModelImpl> get copyWith =>
      __$$TeamModelImplCopyWithImpl<_$TeamModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeamModelImplToJson(this);
  }
}

abstract class _TeamModel implements TeamModel {
  const factory _TeamModel({
    required final String id,
    required final String name,
    @JsonKey(name: 'short_name') final String? shortName,
    final String? country,
    @JsonKey(name: 'country_code') final String? countryCode,
    @JsonKey(name: 'team_type') final String teamType,
    final String? description,
    @JsonKey(name: 'league_name') final String? leagueName,
    final String? region,
    @JsonKey(name: 'competition_ids') final List<String> competitionIds,
    final List<String> aliases,
    @JsonKey(name: 'search_terms') final List<String> searchTerms,
    @JsonKey(name: 'logo_url') final String? logoUrl,
    @JsonKey(name: 'crest_url') final String? crestUrl,
    @JsonKey(name: 'cover_image_url') final String? coverImageUrl,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'is_featured') final bool isFeatured,
    @JsonKey(name: 'is_popular_pick') final bool isPopularPick,
    @JsonKey(name: 'popular_pick_rank') final int? popularPickRank,
    @JsonKey(name: 'fan_count') final int fanCount,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$TeamModelImpl;

  factory _TeamModel.fromJson(Map<String, dynamic> json) =
      _$TeamModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'short_name')
  String? get shortName;
  @override
  String? get country;
  @override
  @JsonKey(name: 'country_code')
  String? get countryCode;
  @override
  @JsonKey(name: 'team_type')
  String get teamType;
  @override
  String? get description;
  @override
  @JsonKey(name: 'league_name')
  String? get leagueName;
  @override
  String? get region;
  @override
  @JsonKey(name: 'competition_ids')
  List<String> get competitionIds;
  @override
  List<String> get aliases;
  @override
  @JsonKey(name: 'search_terms')
  List<String> get searchTerms;
  @override
  @JsonKey(name: 'logo_url')
  String? get logoUrl;
  @override
  @JsonKey(name: 'crest_url')
  String? get crestUrl;
  @override
  @JsonKey(name: 'cover_image_url')
  String? get coverImageUrl;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'is_featured')
  bool get isFeatured;
  @override
  @JsonKey(name: 'is_popular_pick')
  bool get isPopularPick;
  @override
  @JsonKey(name: 'popular_pick_rank')
  int? get popularPickRank;
  @override
  @JsonKey(name: 'fan_count')
  int get fanCount;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of TeamModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamModelImplCopyWith<_$TeamModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
