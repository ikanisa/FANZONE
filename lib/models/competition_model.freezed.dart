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
  @JsonKey(name: 'data_source')
  String get dataSource => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_file')
  String? get sourceFile => throw _privateConstructorUsedError;
  List<String> get seasons => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_count')
  int? get teamCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String? get logoUrl => throw _privateConstructorUsedError; // ── Global launch fields (additive, nullable) ──
  String? get region => throw _privateConstructorUsedError;
  @JsonKey(name: 'competition_type')
  String? get competitionType => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_featured')
  bool get isFeatured => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_tag')
  String? get eventTag => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_date')
  DateTime? get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  DateTime? get endDate => throw _privateConstructorUsedError;

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
    @JsonKey(name: 'data_source') String dataSource,
    @JsonKey(name: 'source_file') String? sourceFile,
    List<String> seasons,
    @JsonKey(name: 'team_count') int? teamCount,
    @JsonKey(name: 'logo_url') String? logoUrl,
    String? region,
    @JsonKey(name: 'competition_type') String? competitionType,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'event_tag') String? eventTag,
    @JsonKey(name: 'start_date') DateTime? startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
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
    Object? dataSource = null,
    Object? sourceFile = freezed,
    Object? seasons = null,
    Object? teamCount = freezed,
    Object? logoUrl = freezed,
    Object? region = freezed,
    Object? competitionType = freezed,
    Object? isFeatured = null,
    Object? eventTag = freezed,
    Object? startDate = freezed,
    Object? endDate = freezed,
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
            dataSource: null == dataSource
                ? _value.dataSource
                : dataSource // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceFile: freezed == sourceFile
                ? _value.sourceFile
                : sourceFile // ignore: cast_nullable_to_non_nullable
                      as String?,
            seasons: null == seasons
                ? _value.seasons
                : seasons // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            teamCount: freezed == teamCount
                ? _value.teamCount
                : teamCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            logoUrl: freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            region: freezed == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as String?,
            competitionType: freezed == competitionType
                ? _value.competitionType
                : competitionType // ignore: cast_nullable_to_non_nullable
                      as String?,
            isFeatured: null == isFeatured
                ? _value.isFeatured
                : isFeatured // ignore: cast_nullable_to_non_nullable
                      as bool,
            eventTag: freezed == eventTag
                ? _value.eventTag
                : eventTag // ignore: cast_nullable_to_non_nullable
                      as String?,
            startDate: freezed == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endDate: freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
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
    @JsonKey(name: 'data_source') String dataSource,
    @JsonKey(name: 'source_file') String? sourceFile,
    List<String> seasons,
    @JsonKey(name: 'team_count') int? teamCount,
    @JsonKey(name: 'logo_url') String? logoUrl,
    String? region,
    @JsonKey(name: 'competition_type') String? competitionType,
    @JsonKey(name: 'is_featured') bool isFeatured,
    @JsonKey(name: 'event_tag') String? eventTag,
    @JsonKey(name: 'start_date') DateTime? startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
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
    Object? dataSource = null,
    Object? sourceFile = freezed,
    Object? seasons = null,
    Object? teamCount = freezed,
    Object? logoUrl = freezed,
    Object? region = freezed,
    Object? competitionType = freezed,
    Object? isFeatured = null,
    Object? eventTag = freezed,
    Object? startDate = freezed,
    Object? endDate = freezed,
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
        dataSource: null == dataSource
            ? _value.dataSource
            : dataSource // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceFile: freezed == sourceFile
            ? _value.sourceFile
            : sourceFile // ignore: cast_nullable_to_non_nullable
                  as String?,
        seasons: null == seasons
            ? _value._seasons
            : seasons // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        teamCount: freezed == teamCount
            ? _value.teamCount
            : teamCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        logoUrl: freezed == logoUrl
            ? _value.logoUrl
            : logoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        region: freezed == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as String?,
        competitionType: freezed == competitionType
            ? _value.competitionType
            : competitionType // ignore: cast_nullable_to_non_nullable
                  as String?,
        isFeatured: null == isFeatured
            ? _value.isFeatured
            : isFeatured // ignore: cast_nullable_to_non_nullable
                  as bool,
        eventTag: freezed == eventTag
            ? _value.eventTag
            : eventTag // ignore: cast_nullable_to_non_nullable
                  as String?,
        startDate: freezed == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endDate: freezed == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CompetitionModelImpl implements _CompetitionModel {
  const _$CompetitionModelImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'short_name') required this.shortName,
    required this.country,
    this.tier = 1,
    @JsonKey(name: 'data_source') required this.dataSource,
    @JsonKey(name: 'source_file') this.sourceFile,
    final List<String> seasons = const [],
    @JsonKey(name: 'team_count') this.teamCount,
    @JsonKey(name: 'logo_url') this.logoUrl,
    this.region,
    @JsonKey(name: 'competition_type') this.competitionType,
    @JsonKey(name: 'is_featured') this.isFeatured = false,
    @JsonKey(name: 'event_tag') this.eventTag,
    @JsonKey(name: 'start_date') this.startDate,
    @JsonKey(name: 'end_date') this.endDate,
  }) : _seasons = seasons;

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
  final String country;
  @override
  @JsonKey()
  final int tier;
  @override
  @JsonKey(name: 'data_source')
  final String dataSource;
  @override
  @JsonKey(name: 'source_file')
  final String? sourceFile;
  final List<String> _seasons;
  @override
  @JsonKey()
  List<String> get seasons {
    if (_seasons is EqualUnmodifiableListView) return _seasons;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_seasons);
  }

  @override
  @JsonKey(name: 'team_count')
  final int? teamCount;
  @override
  @JsonKey(name: 'logo_url')
  final String? logoUrl;
  // ── Global launch fields (additive, nullable) ──
  @override
  final String? region;
  @override
  @JsonKey(name: 'competition_type')
  final String? competitionType;
  @override
  @JsonKey(name: 'is_featured')
  final bool isFeatured;
  @override
  @JsonKey(name: 'event_tag')
  final String? eventTag;
  @override
  @JsonKey(name: 'start_date')
  final DateTime? startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime? endDate;

  @override
  String toString() {
    return 'CompetitionModel(id: $id, name: $name, shortName: $shortName, country: $country, tier: $tier, dataSource: $dataSource, sourceFile: $sourceFile, seasons: $seasons, teamCount: $teamCount, logoUrl: $logoUrl, region: $region, competitionType: $competitionType, isFeatured: $isFeatured, eventTag: $eventTag, startDate: $startDate, endDate: $endDate)';
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
            (identical(other.dataSource, dataSource) ||
                other.dataSource == dataSource) &&
            (identical(other.sourceFile, sourceFile) ||
                other.sourceFile == sourceFile) &&
            const DeepCollectionEquality().equals(other._seasons, _seasons) &&
            (identical(other.teamCount, teamCount) ||
                other.teamCount == teamCount) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.competitionType, competitionType) ||
                other.competitionType == competitionType) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.eventTag, eventTag) ||
                other.eventTag == eventTag) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate));
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
    dataSource,
    sourceFile,
    const DeepCollectionEquality().hash(_seasons),
    teamCount,
    logoUrl,
    region,
    competitionType,
    isFeatured,
    eventTag,
    startDate,
    endDate,
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

abstract class _CompetitionModel implements CompetitionModel {
  const factory _CompetitionModel({
    required final String id,
    required final String name,
    @JsonKey(name: 'short_name') required final String shortName,
    required final String country,
    final int tier,
    @JsonKey(name: 'data_source') required final String dataSource,
    @JsonKey(name: 'source_file') final String? sourceFile,
    final List<String> seasons,
    @JsonKey(name: 'team_count') final int? teamCount,
    @JsonKey(name: 'logo_url') final String? logoUrl,
    final String? region,
    @JsonKey(name: 'competition_type') final String? competitionType,
    @JsonKey(name: 'is_featured') final bool isFeatured,
    @JsonKey(name: 'event_tag') final String? eventTag,
    @JsonKey(name: 'start_date') final DateTime? startDate,
    @JsonKey(name: 'end_date') final DateTime? endDate,
  }) = _$CompetitionModelImpl;

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
  @JsonKey(name: 'data_source')
  String get dataSource;
  @override
  @JsonKey(name: 'source_file')
  String? get sourceFile;
  @override
  List<String> get seasons;
  @override
  @JsonKey(name: 'team_count')
  int? get teamCount;
  @override
  @JsonKey(name: 'logo_url')
  String? get logoUrl; // ── Global launch fields (additive, nullable) ──
  @override
  String? get region;
  @override
  @JsonKey(name: 'competition_type')
  String? get competitionType;
  @override
  @JsonKey(name: 'is_featured')
  bool get isFeatured;
  @override
  @JsonKey(name: 'event_tag')
  String? get eventTag;
  @override
  @JsonKey(name: 'start_date')
  DateTime? get startDate;
  @override
  @JsonKey(name: 'end_date')
  DateTime? get endDate;

  /// Create a copy of CompetitionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CompetitionModelImplCopyWith<_$CompetitionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
