// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MatchModel _$MatchModelFromJson(Map<String, dynamic> json) {
  return _MatchModel.fromJson(json);
}

/// @nodoc
mixin _$MatchModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'competition_id')
  String get competitionId => throw _privateConstructorUsedError;
  String get season => throw _privateConstructorUsedError;
  String? get round => throw _privateConstructorUsedError;
  @JsonKey(name: 'match_group')
  String? get matchGroup => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'kickoff_time')
  String? get kickoffTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'home_team_id')
  String? get homeTeamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'away_team_id')
  String? get awayTeamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'home_team')
  String get homeTeam => throw _privateConstructorUsedError;
  @JsonKey(name: 'away_team')
  String get awayTeam => throw _privateConstructorUsedError;
  @JsonKey(name: 'ft_home')
  int? get ftHome => throw _privateConstructorUsedError;
  @JsonKey(name: 'ft_away')
  int? get ftAway => throw _privateConstructorUsedError;
  @JsonKey(name: 'ht_home')
  int? get htHome => throw _privateConstructorUsedError;
  @JsonKey(name: 'ht_away')
  int? get htAway => throw _privateConstructorUsedError;
  @JsonKey(name: 'et_home')
  int? get etHome => throw _privateConstructorUsedError;
  @JsonKey(name: 'et_away')
  int? get etAway => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get venue => throw _privateConstructorUsedError;
  @JsonKey(name: 'data_source')
  String get dataSource => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_url')
  String? get sourceUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'home_logo_url')
  String? get homeLogoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'away_logo_url')
  String? get awayLogoUrl => throw _privateConstructorUsedError;

  /// Serializes this MatchModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchModelCopyWith<MatchModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchModelCopyWith<$Res> {
  factory $MatchModelCopyWith(
    MatchModel value,
    $Res Function(MatchModel) then,
  ) = _$MatchModelCopyWithImpl<$Res, MatchModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'competition_id') String competitionId,
    String season,
    String? round,
    @JsonKey(name: 'match_group') String? matchGroup,
    DateTime date,
    @JsonKey(name: 'kickoff_time') String? kickoffTime,
    @JsonKey(name: 'home_team_id') String? homeTeamId,
    @JsonKey(name: 'away_team_id') String? awayTeamId,
    @JsonKey(name: 'home_team') String homeTeam,
    @JsonKey(name: 'away_team') String awayTeam,
    @JsonKey(name: 'ft_home') int? ftHome,
    @JsonKey(name: 'ft_away') int? ftAway,
    @JsonKey(name: 'ht_home') int? htHome,
    @JsonKey(name: 'ht_away') int? htAway,
    @JsonKey(name: 'et_home') int? etHome,
    @JsonKey(name: 'et_away') int? etAway,
    String status,
    String? venue,
    @JsonKey(name: 'data_source') String dataSource,
    @JsonKey(name: 'source_url') String? sourceUrl,
    @JsonKey(name: 'home_logo_url') String? homeLogoUrl,
    @JsonKey(name: 'away_logo_url') String? awayLogoUrl,
  });
}

/// @nodoc
class _$MatchModelCopyWithImpl<$Res, $Val extends MatchModel>
    implements $MatchModelCopyWith<$Res> {
  _$MatchModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? competitionId = null,
    Object? season = null,
    Object? round = freezed,
    Object? matchGroup = freezed,
    Object? date = null,
    Object? kickoffTime = freezed,
    Object? homeTeamId = freezed,
    Object? awayTeamId = freezed,
    Object? homeTeam = null,
    Object? awayTeam = null,
    Object? ftHome = freezed,
    Object? ftAway = freezed,
    Object? htHome = freezed,
    Object? htAway = freezed,
    Object? etHome = freezed,
    Object? etAway = freezed,
    Object? status = null,
    Object? venue = freezed,
    Object? dataSource = null,
    Object? sourceUrl = freezed,
    Object? homeLogoUrl = freezed,
    Object? awayLogoUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            competitionId: null == competitionId
                ? _value.competitionId
                : competitionId // ignore: cast_nullable_to_non_nullable
                      as String,
            season: null == season
                ? _value.season
                : season // ignore: cast_nullable_to_non_nullable
                      as String,
            round: freezed == round
                ? _value.round
                : round // ignore: cast_nullable_to_non_nullable
                      as String?,
            matchGroup: freezed == matchGroup
                ? _value.matchGroup
                : matchGroup // ignore: cast_nullable_to_non_nullable
                      as String?,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            kickoffTime: freezed == kickoffTime
                ? _value.kickoffTime
                : kickoffTime // ignore: cast_nullable_to_non_nullable
                      as String?,
            homeTeamId: freezed == homeTeamId
                ? _value.homeTeamId
                : homeTeamId // ignore: cast_nullable_to_non_nullable
                      as String?,
            awayTeamId: freezed == awayTeamId
                ? _value.awayTeamId
                : awayTeamId // ignore: cast_nullable_to_non_nullable
                      as String?,
            homeTeam: null == homeTeam
                ? _value.homeTeam
                : homeTeam // ignore: cast_nullable_to_non_nullable
                      as String,
            awayTeam: null == awayTeam
                ? _value.awayTeam
                : awayTeam // ignore: cast_nullable_to_non_nullable
                      as String,
            ftHome: freezed == ftHome
                ? _value.ftHome
                : ftHome // ignore: cast_nullable_to_non_nullable
                      as int?,
            ftAway: freezed == ftAway
                ? _value.ftAway
                : ftAway // ignore: cast_nullable_to_non_nullable
                      as int?,
            htHome: freezed == htHome
                ? _value.htHome
                : htHome // ignore: cast_nullable_to_non_nullable
                      as int?,
            htAway: freezed == htAway
                ? _value.htAway
                : htAway // ignore: cast_nullable_to_non_nullable
                      as int?,
            etHome: freezed == etHome
                ? _value.etHome
                : etHome // ignore: cast_nullable_to_non_nullable
                      as int?,
            etAway: freezed == etAway
                ? _value.etAway
                : etAway // ignore: cast_nullable_to_non_nullable
                      as int?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            venue: freezed == venue
                ? _value.venue
                : venue // ignore: cast_nullable_to_non_nullable
                      as String?,
            dataSource: null == dataSource
                ? _value.dataSource
                : dataSource // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceUrl: freezed == sourceUrl
                ? _value.sourceUrl
                : sourceUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            homeLogoUrl: freezed == homeLogoUrl
                ? _value.homeLogoUrl
                : homeLogoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            awayLogoUrl: freezed == awayLogoUrl
                ? _value.awayLogoUrl
                : awayLogoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MatchModelImplCopyWith<$Res>
    implements $MatchModelCopyWith<$Res> {
  factory _$$MatchModelImplCopyWith(
    _$MatchModelImpl value,
    $Res Function(_$MatchModelImpl) then,
  ) = __$$MatchModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'competition_id') String competitionId,
    String season,
    String? round,
    @JsonKey(name: 'match_group') String? matchGroup,
    DateTime date,
    @JsonKey(name: 'kickoff_time') String? kickoffTime,
    @JsonKey(name: 'home_team_id') String? homeTeamId,
    @JsonKey(name: 'away_team_id') String? awayTeamId,
    @JsonKey(name: 'home_team') String homeTeam,
    @JsonKey(name: 'away_team') String awayTeam,
    @JsonKey(name: 'ft_home') int? ftHome,
    @JsonKey(name: 'ft_away') int? ftAway,
    @JsonKey(name: 'ht_home') int? htHome,
    @JsonKey(name: 'ht_away') int? htAway,
    @JsonKey(name: 'et_home') int? etHome,
    @JsonKey(name: 'et_away') int? etAway,
    String status,
    String? venue,
    @JsonKey(name: 'data_source') String dataSource,
    @JsonKey(name: 'source_url') String? sourceUrl,
    @JsonKey(name: 'home_logo_url') String? homeLogoUrl,
    @JsonKey(name: 'away_logo_url') String? awayLogoUrl,
  });
}

/// @nodoc
class __$$MatchModelImplCopyWithImpl<$Res>
    extends _$MatchModelCopyWithImpl<$Res, _$MatchModelImpl>
    implements _$$MatchModelImplCopyWith<$Res> {
  __$$MatchModelImplCopyWithImpl(
    _$MatchModelImpl _value,
    $Res Function(_$MatchModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MatchModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? competitionId = null,
    Object? season = null,
    Object? round = freezed,
    Object? matchGroup = freezed,
    Object? date = null,
    Object? kickoffTime = freezed,
    Object? homeTeamId = freezed,
    Object? awayTeamId = freezed,
    Object? homeTeam = null,
    Object? awayTeam = null,
    Object? ftHome = freezed,
    Object? ftAway = freezed,
    Object? htHome = freezed,
    Object? htAway = freezed,
    Object? etHome = freezed,
    Object? etAway = freezed,
    Object? status = null,
    Object? venue = freezed,
    Object? dataSource = null,
    Object? sourceUrl = freezed,
    Object? homeLogoUrl = freezed,
    Object? awayLogoUrl = freezed,
  }) {
    return _then(
      _$MatchModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        competitionId: null == competitionId
            ? _value.competitionId
            : competitionId // ignore: cast_nullable_to_non_nullable
                  as String,
        season: null == season
            ? _value.season
            : season // ignore: cast_nullable_to_non_nullable
                  as String,
        round: freezed == round
            ? _value.round
            : round // ignore: cast_nullable_to_non_nullable
                  as String?,
        matchGroup: freezed == matchGroup
            ? _value.matchGroup
            : matchGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        kickoffTime: freezed == kickoffTime
            ? _value.kickoffTime
            : kickoffTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        homeTeamId: freezed == homeTeamId
            ? _value.homeTeamId
            : homeTeamId // ignore: cast_nullable_to_non_nullable
                  as String?,
        awayTeamId: freezed == awayTeamId
            ? _value.awayTeamId
            : awayTeamId // ignore: cast_nullable_to_non_nullable
                  as String?,
        homeTeam: null == homeTeam
            ? _value.homeTeam
            : homeTeam // ignore: cast_nullable_to_non_nullable
                  as String,
        awayTeam: null == awayTeam
            ? _value.awayTeam
            : awayTeam // ignore: cast_nullable_to_non_nullable
                  as String,
        ftHome: freezed == ftHome
            ? _value.ftHome
            : ftHome // ignore: cast_nullable_to_non_nullable
                  as int?,
        ftAway: freezed == ftAway
            ? _value.ftAway
            : ftAway // ignore: cast_nullable_to_non_nullable
                  as int?,
        htHome: freezed == htHome
            ? _value.htHome
            : htHome // ignore: cast_nullable_to_non_nullable
                  as int?,
        htAway: freezed == htAway
            ? _value.htAway
            : htAway // ignore: cast_nullable_to_non_nullable
                  as int?,
        etHome: freezed == etHome
            ? _value.etHome
            : etHome // ignore: cast_nullable_to_non_nullable
                  as int?,
        etAway: freezed == etAway
            ? _value.etAway
            : etAway // ignore: cast_nullable_to_non_nullable
                  as int?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        venue: freezed == venue
            ? _value.venue
            : venue // ignore: cast_nullable_to_non_nullable
                  as String?,
        dataSource: null == dataSource
            ? _value.dataSource
            : dataSource // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceUrl: freezed == sourceUrl
            ? _value.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        homeLogoUrl: freezed == homeLogoUrl
            ? _value.homeLogoUrl
            : homeLogoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        awayLogoUrl: freezed == awayLogoUrl
            ? _value.awayLogoUrl
            : awayLogoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MatchModelImpl extends _MatchModel {
  const _$MatchModelImpl({
    required this.id,
    @JsonKey(name: 'competition_id') required this.competitionId,
    required this.season,
    this.round,
    @JsonKey(name: 'match_group') this.matchGroup,
    required this.date,
    @JsonKey(name: 'kickoff_time') this.kickoffTime,
    @JsonKey(name: 'home_team_id') this.homeTeamId,
    @JsonKey(name: 'away_team_id') this.awayTeamId,
    @JsonKey(name: 'home_team') required this.homeTeam,
    @JsonKey(name: 'away_team') required this.awayTeam,
    @JsonKey(name: 'ft_home') this.ftHome,
    @JsonKey(name: 'ft_away') this.ftAway,
    @JsonKey(name: 'ht_home') this.htHome,
    @JsonKey(name: 'ht_away') this.htAway,
    @JsonKey(name: 'et_home') this.etHome,
    @JsonKey(name: 'et_away') this.etAway,
    this.status = 'upcoming',
    this.venue,
    @JsonKey(name: 'data_source') required this.dataSource,
    @JsonKey(name: 'source_url') this.sourceUrl,
    @JsonKey(name: 'home_logo_url') this.homeLogoUrl,
    @JsonKey(name: 'away_logo_url') this.awayLogoUrl,
  }) : super._();

  factory _$MatchModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'competition_id')
  final String competitionId;
  @override
  final String season;
  @override
  final String? round;
  @override
  @JsonKey(name: 'match_group')
  final String? matchGroup;
  @override
  final DateTime date;
  @override
  @JsonKey(name: 'kickoff_time')
  final String? kickoffTime;
  @override
  @JsonKey(name: 'home_team_id')
  final String? homeTeamId;
  @override
  @JsonKey(name: 'away_team_id')
  final String? awayTeamId;
  @override
  @JsonKey(name: 'home_team')
  final String homeTeam;
  @override
  @JsonKey(name: 'away_team')
  final String awayTeam;
  @override
  @JsonKey(name: 'ft_home')
  final int? ftHome;
  @override
  @JsonKey(name: 'ft_away')
  final int? ftAway;
  @override
  @JsonKey(name: 'ht_home')
  final int? htHome;
  @override
  @JsonKey(name: 'ht_away')
  final int? htAway;
  @override
  @JsonKey(name: 'et_home')
  final int? etHome;
  @override
  @JsonKey(name: 'et_away')
  final int? etAway;
  @override
  @JsonKey()
  final String status;
  @override
  final String? venue;
  @override
  @JsonKey(name: 'data_source')
  final String dataSource;
  @override
  @JsonKey(name: 'source_url')
  final String? sourceUrl;
  @override
  @JsonKey(name: 'home_logo_url')
  final String? homeLogoUrl;
  @override
  @JsonKey(name: 'away_logo_url')
  final String? awayLogoUrl;

  @override
  String toString() {
    return 'MatchModel(id: $id, competitionId: $competitionId, season: $season, round: $round, matchGroup: $matchGroup, date: $date, kickoffTime: $kickoffTime, homeTeamId: $homeTeamId, awayTeamId: $awayTeamId, homeTeam: $homeTeam, awayTeam: $awayTeam, ftHome: $ftHome, ftAway: $ftAway, htHome: $htHome, htAway: $htAway, etHome: $etHome, etAway: $etAway, status: $status, venue: $venue, dataSource: $dataSource, sourceUrl: $sourceUrl, homeLogoUrl: $homeLogoUrl, awayLogoUrl: $awayLogoUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.competitionId, competitionId) ||
                other.competitionId == competitionId) &&
            (identical(other.season, season) || other.season == season) &&
            (identical(other.round, round) || other.round == round) &&
            (identical(other.matchGroup, matchGroup) ||
                other.matchGroup == matchGroup) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.kickoffTime, kickoffTime) ||
                other.kickoffTime == kickoffTime) &&
            (identical(other.homeTeamId, homeTeamId) ||
                other.homeTeamId == homeTeamId) &&
            (identical(other.awayTeamId, awayTeamId) ||
                other.awayTeamId == awayTeamId) &&
            (identical(other.homeTeam, homeTeam) ||
                other.homeTeam == homeTeam) &&
            (identical(other.awayTeam, awayTeam) ||
                other.awayTeam == awayTeam) &&
            (identical(other.ftHome, ftHome) || other.ftHome == ftHome) &&
            (identical(other.ftAway, ftAway) || other.ftAway == ftAway) &&
            (identical(other.htHome, htHome) || other.htHome == htHome) &&
            (identical(other.htAway, htAway) || other.htAway == htAway) &&
            (identical(other.etHome, etHome) || other.etHome == etHome) &&
            (identical(other.etAway, etAway) || other.etAway == etAway) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.venue, venue) || other.venue == venue) &&
            (identical(other.dataSource, dataSource) ||
                other.dataSource == dataSource) &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl) &&
            (identical(other.homeLogoUrl, homeLogoUrl) ||
                other.homeLogoUrl == homeLogoUrl) &&
            (identical(other.awayLogoUrl, awayLogoUrl) ||
                other.awayLogoUrl == awayLogoUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    competitionId,
    season,
    round,
    matchGroup,
    date,
    kickoffTime,
    homeTeamId,
    awayTeamId,
    homeTeam,
    awayTeam,
    ftHome,
    ftAway,
    htHome,
    htAway,
    etHome,
    etAway,
    status,
    venue,
    dataSource,
    sourceUrl,
    homeLogoUrl,
    awayLogoUrl,
  ]);

  /// Create a copy of MatchModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchModelImplCopyWith<_$MatchModelImpl> get copyWith =>
      __$$MatchModelImplCopyWithImpl<_$MatchModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchModelImplToJson(this);
  }
}

abstract class _MatchModel extends MatchModel {
  const factory _MatchModel({
    required final String id,
    @JsonKey(name: 'competition_id') required final String competitionId,
    required final String season,
    final String? round,
    @JsonKey(name: 'match_group') final String? matchGroup,
    required final DateTime date,
    @JsonKey(name: 'kickoff_time') final String? kickoffTime,
    @JsonKey(name: 'home_team_id') final String? homeTeamId,
    @JsonKey(name: 'away_team_id') final String? awayTeamId,
    @JsonKey(name: 'home_team') required final String homeTeam,
    @JsonKey(name: 'away_team') required final String awayTeam,
    @JsonKey(name: 'ft_home') final int? ftHome,
    @JsonKey(name: 'ft_away') final int? ftAway,
    @JsonKey(name: 'ht_home') final int? htHome,
    @JsonKey(name: 'ht_away') final int? htAway,
    @JsonKey(name: 'et_home') final int? etHome,
    @JsonKey(name: 'et_away') final int? etAway,
    final String status,
    final String? venue,
    @JsonKey(name: 'data_source') required final String dataSource,
    @JsonKey(name: 'source_url') final String? sourceUrl,
    @JsonKey(name: 'home_logo_url') final String? homeLogoUrl,
    @JsonKey(name: 'away_logo_url') final String? awayLogoUrl,
  }) = _$MatchModelImpl;
  const _MatchModel._() : super._();

  factory _MatchModel.fromJson(Map<String, dynamic> json) =
      _$MatchModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'competition_id')
  String get competitionId;
  @override
  String get season;
  @override
  String? get round;
  @override
  @JsonKey(name: 'match_group')
  String? get matchGroup;
  @override
  DateTime get date;
  @override
  @JsonKey(name: 'kickoff_time')
  String? get kickoffTime;
  @override
  @JsonKey(name: 'home_team_id')
  String? get homeTeamId;
  @override
  @JsonKey(name: 'away_team_id')
  String? get awayTeamId;
  @override
  @JsonKey(name: 'home_team')
  String get homeTeam;
  @override
  @JsonKey(name: 'away_team')
  String get awayTeam;
  @override
  @JsonKey(name: 'ft_home')
  int? get ftHome;
  @override
  @JsonKey(name: 'ft_away')
  int? get ftAway;
  @override
  @JsonKey(name: 'ht_home')
  int? get htHome;
  @override
  @JsonKey(name: 'ht_away')
  int? get htAway;
  @override
  @JsonKey(name: 'et_home')
  int? get etHome;
  @override
  @JsonKey(name: 'et_away')
  int? get etAway;
  @override
  String get status;
  @override
  String? get venue;
  @override
  @JsonKey(name: 'data_source')
  String get dataSource;
  @override
  @JsonKey(name: 'source_url')
  String? get sourceUrl;
  @override
  @JsonKey(name: 'home_logo_url')
  String? get homeLogoUrl;
  @override
  @JsonKey(name: 'away_logo_url')
  String? get awayLogoUrl;

  /// Create a copy of MatchModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchModelImplCopyWith<_$MatchModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
