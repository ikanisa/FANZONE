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
  String? get slug => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'league_name')
  String? get leagueName => throw _privateConstructorUsedError;
  @JsonKey(name: 'competition_ids')
  List<String> get competitionIds => throw _privateConstructorUsedError;
  List<String> get aliases => throw _privateConstructorUsedError;
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
  @JsonKey(name: 'fet_contributions_enabled')
  bool get fetContributionsEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'fiat_contributions_enabled')
  bool get fiatContributionsEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'fiat_contribution_mode')
  String? get fiatContributionMode => throw _privateConstructorUsedError;
  @JsonKey(name: 'fiat_contribution_link')
  String? get fiatContributionLink => throw _privateConstructorUsedError;
  @JsonKey(name: 'fan_count')
  int get fanCount => throw _privateConstructorUsedError;

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
    String? slug,
    String? country,
    String? description,
    @JsonKey(name: 'league_name') String? leagueName,
    @JsonKey(name: 'competition_ids') List<String> competitionIds,
    List<String> aliases,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'crest_url') String? crestUrl,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'fet_contributions_enabled') bool fetContributionsEnabled,
    @JsonKey(name: 'fiat_contributions_enabled') bool fiatContributionsEnabled,
    @JsonKey(name: 'fiat_contribution_mode') String? fiatContributionMode,
    @JsonKey(name: 'fiat_contribution_link') String? fiatContributionLink,
    @JsonKey(name: 'fan_count') int fanCount,
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
    Object? slug = freezed,
    Object? country = freezed,
    Object? description = freezed,
    Object? leagueName = freezed,
    Object? competitionIds = null,
    Object? aliases = null,
    Object? logoUrl = freezed,
    Object? crestUrl = freezed,
    Object? coverImageUrl = freezed,
    Object? isActive = null,
    Object? isFeatured = null,
    Object? fetContributionsEnabled = null,
    Object? fiatContributionsEnabled = null,
    Object? fiatContributionMode = freezed,
    Object? fiatContributionLink = freezed,
    Object? fanCount = null,
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
            slug: freezed == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String?,
            country: freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            leagueName: freezed == leagueName
                ? _value.leagueName
                : leagueName // ignore: cast_nullable_to_non_nullable
                      as String?,
            competitionIds: null == competitionIds
                ? _value.competitionIds
                : competitionIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            aliases: null == aliases
                ? _value.aliases
                : aliases // ignore: cast_nullable_to_non_nullable
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
            fetContributionsEnabled: null == fetContributionsEnabled
                ? _value.fetContributionsEnabled
                : fetContributionsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            fiatContributionsEnabled: null == fiatContributionsEnabled
                ? _value.fiatContributionsEnabled
                : fiatContributionsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            fiatContributionMode: freezed == fiatContributionMode
                ? _value.fiatContributionMode
                : fiatContributionMode // ignore: cast_nullable_to_non_nullable
                      as String?,
            fiatContributionLink: freezed == fiatContributionLink
                ? _value.fiatContributionLink
                : fiatContributionLink // ignore: cast_nullable_to_non_nullable
                      as String?,
            fanCount: null == fanCount
                ? _value.fanCount
                : fanCount // ignore: cast_nullable_to_non_nullable
                      as int,
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
    String? slug,
    String? country,
    String? description,
    @JsonKey(name: 'league_name') String? leagueName,
    @JsonKey(name: 'competition_ids') List<String> competitionIds,
    List<String> aliases,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'crest_url') String? crestUrl,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'fet_contributions_enabled') bool fetContributionsEnabled,
    @JsonKey(name: 'fiat_contributions_enabled') bool fiatContributionsEnabled,
    @JsonKey(name: 'fiat_contribution_mode') String? fiatContributionMode,
    @JsonKey(name: 'fiat_contribution_link') String? fiatContributionLink,
    @JsonKey(name: 'fan_count') int fanCount,
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
    Object? slug = freezed,
    Object? country = freezed,
    Object? description = freezed,
    Object? leagueName = freezed,
    Object? competitionIds = null,
    Object? aliases = null,
    Object? logoUrl = freezed,
    Object? crestUrl = freezed,
    Object? coverImageUrl = freezed,
    Object? isActive = null,
    Object? isFeatured = null,
    Object? fetContributionsEnabled = null,
    Object? fiatContributionsEnabled = null,
    Object? fiatContributionMode = freezed,
    Object? fiatContributionLink = freezed,
    Object? fanCount = null,
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
        slug: freezed == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String?,
        country: freezed == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        leagueName: freezed == leagueName
            ? _value.leagueName
            : leagueName // ignore: cast_nullable_to_non_nullable
                  as String?,
        competitionIds: null == competitionIds
            ? _value._competitionIds
            : competitionIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        aliases: null == aliases
            ? _value._aliases
            : aliases // ignore: cast_nullable_to_non_nullable
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
        fetContributionsEnabled: null == fetContributionsEnabled
            ? _value.fetContributionsEnabled
            : fetContributionsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        fiatContributionsEnabled: null == fiatContributionsEnabled
            ? _value.fiatContributionsEnabled
            : fiatContributionsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        fiatContributionMode: freezed == fiatContributionMode
            ? _value.fiatContributionMode
            : fiatContributionMode // ignore: cast_nullable_to_non_nullable
                  as String?,
        fiatContributionLink: freezed == fiatContributionLink
            ? _value.fiatContributionLink
            : fiatContributionLink // ignore: cast_nullable_to_non_nullable
                  as String?,
        fanCount: null == fanCount
            ? _value.fanCount
            : fanCount // ignore: cast_nullable_to_non_nullable
                  as int,
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
    this.slug,
    this.country,
    this.description,
    @JsonKey(name: 'league_name') this.leagueName,
    @JsonKey(name: 'competition_ids')
    final List<String> competitionIds = const [],
    final List<String> aliases = const [],
    @JsonKey(name: 'logo_url') this.logoUrl,
    @JsonKey(name: 'crest_url') this.crestUrl,
    @JsonKey(name: 'cover_image_url') this.coverImageUrl,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'is_featured') this.isFeatured = false,
    @JsonKey(name: 'fet_contributions_enabled')
    this.fetContributionsEnabled = false,
    @JsonKey(name: 'fiat_contributions_enabled')
    this.fiatContributionsEnabled = false,
    @JsonKey(name: 'fiat_contribution_mode') this.fiatContributionMode,
    @JsonKey(name: 'fiat_contribution_link') this.fiatContributionLink,
    @JsonKey(name: 'fan_count') this.fanCount = 0,
  }) : _competitionIds = competitionIds,
       _aliases = aliases;

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
  final String? slug;
  @override
  final String? country;
  @override
  final String? description;
  @override
  @JsonKey(name: 'league_name')
  final String? leagueName;
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
  @JsonKey(name: 'fet_contributions_enabled')
  final bool fetContributionsEnabled;
  @override
  @JsonKey(name: 'fiat_contributions_enabled')
  final bool fiatContributionsEnabled;
  @override
  @JsonKey(name: 'fiat_contribution_mode')
  final String? fiatContributionMode;
  @override
  @JsonKey(name: 'fiat_contribution_link')
  final String? fiatContributionLink;
  @override
  @JsonKey(name: 'fan_count')
  final int fanCount;

  @override
  String toString() {
    return 'TeamModel(id: $id, name: $name, shortName: $shortName, slug: $slug, country: $country, description: $description, leagueName: $leagueName, competitionIds: $competitionIds, aliases: $aliases, logoUrl: $logoUrl, crestUrl: $crestUrl, coverImageUrl: $coverImageUrl, isActive: $isActive, isFeatured: $isFeatured, fetContributionsEnabled: $fetContributionsEnabled, fiatContributionsEnabled: $fiatContributionsEnabled, fiatContributionMode: $fiatContributionMode, fiatContributionLink: $fiatContributionLink, fanCount: $fanCount)';
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
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.leagueName, leagueName) ||
                other.leagueName == leagueName) &&
            const DeepCollectionEquality().equals(
              other._competitionIds,
              _competitionIds,
            ) &&
            const DeepCollectionEquality().equals(other._aliases, _aliases) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.crestUrl, crestUrl) ||
                other.crestUrl == crestUrl) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(
                  other.fetContributionsEnabled,
                  fetContributionsEnabled,
                ) ||
                other.fetContributionsEnabled == fetContributionsEnabled) &&
            (identical(
                  other.fiatContributionsEnabled,
                  fiatContributionsEnabled,
                ) ||
                other.fiatContributionsEnabled == fiatContributionsEnabled) &&
            (identical(other.fiatContributionMode, fiatContributionMode) ||
                other.fiatContributionMode == fiatContributionMode) &&
            (identical(other.fiatContributionLink, fiatContributionLink) ||
                other.fiatContributionLink == fiatContributionLink) &&
            (identical(other.fanCount, fanCount) ||
                other.fanCount == fanCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    name,
    shortName,
    slug,
    country,
    description,
    leagueName,
    const DeepCollectionEquality().hash(_competitionIds),
    const DeepCollectionEquality().hash(_aliases),
    logoUrl,
    crestUrl,
    coverImageUrl,
    isActive,
    isFeatured,
    fetContributionsEnabled,
    fiatContributionsEnabled,
    fiatContributionMode,
    fiatContributionLink,
    fanCount,
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
    final String? slug,
    final String? country,
    final String? description,
    @JsonKey(name: 'league_name') final String? leagueName,
    @JsonKey(name: 'competition_ids') final List<String> competitionIds,
    final List<String> aliases,
    @JsonKey(name: 'logo_url') final String? logoUrl,
    @JsonKey(name: 'crest_url') final String? crestUrl,
    @JsonKey(name: 'cover_image_url') final String? coverImageUrl,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'is_featured') final bool isFeatured,
    @JsonKey(name: 'fet_contributions_enabled')
    final bool fetContributionsEnabled,
    @JsonKey(name: 'fiat_contributions_enabled')
    final bool fiatContributionsEnabled,
    @JsonKey(name: 'fiat_contribution_mode') final String? fiatContributionMode,
    @JsonKey(name: 'fiat_contribution_link') final String? fiatContributionLink,
    @JsonKey(name: 'fan_count') final int fanCount,
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
  String? get slug;
  @override
  String? get country;
  @override
  String? get description;
  @override
  @JsonKey(name: 'league_name')
  String? get leagueName;
  @override
  @JsonKey(name: 'competition_ids')
  List<String> get competitionIds;
  @override
  List<String> get aliases;
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
  @JsonKey(name: 'fet_contributions_enabled')
  bool get fetContributionsEnabled;
  @override
  @JsonKey(name: 'fiat_contributions_enabled')
  bool get fiatContributionsEnabled;
  @override
  @JsonKey(name: 'fiat_contribution_mode')
  String? get fiatContributionMode;
  @override
  @JsonKey(name: 'fiat_contribution_link')
  String? get fiatContributionLink;
  @override
  @JsonKey(name: 'fan_count')
  int get fanCount;

  /// Create a copy of TeamModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamModelImplCopyWith<_$TeamModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
