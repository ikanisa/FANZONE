// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MatchModelImpl _$$MatchModelImplFromJson(Map<String, dynamic> json) =>
    _$MatchModelImpl(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      competitionName: json['competition_name'] as String?,
      seasonId: json['season_id'] as String?,
      seasonLabel: json['season_label'] as String?,
      stage: json['stage'] as String?,
      round: json['round'] as String?,
      matchdayOrRound: json['matchday_or_round'] as String?,
      date: DateTime.parse(json['date'] as String),
      matchDate: json['match_date'] == null
          ? null
          : DateTime.parse(json['match_date'] as String),
      kickoffTime: json['kickoff_time'] as String?,
      homeTeamId: json['home_team_id'] as String?,
      awayTeamId: json['away_team_id'] as String?,
      homeTeam: json['home_team'] as String,
      awayTeam: json['away_team'] as String,
      ftHome: (json['ft_home'] as num?)?.toInt(),
      ftAway: (json['ft_away'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'upcoming',
      liveMinute: (json['live_minute'] as num?)?.toInt(),
      resultCode: json['result_code'] as String?,
      isNeutral: json['is_neutral'] as bool? ?? false,
      dataSource: json['data_source'] as String? ?? 'manual',
      sourceUrl: json['source_url'] as String?,
      notes: json['notes'] as String?,
      homeLogoUrl: json['home_logo_url'] as String?,
      awayLogoUrl: json['away_logo_url'] as String?,
    );

Map<String, dynamic> _$$MatchModelImplToJson(_$MatchModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'competition_id': instance.competitionId,
      'competition_name': instance.competitionName,
      'season_id': instance.seasonId,
      'season_label': instance.seasonLabel,
      'stage': instance.stage,
      'round': instance.round,
      'matchday_or_round': instance.matchdayOrRound,
      'date': instance.date.toIso8601String(),
      'match_date': instance.matchDate?.toIso8601String(),
      'kickoff_time': instance.kickoffTime,
      'home_team_id': instance.homeTeamId,
      'away_team_id': instance.awayTeamId,
      'home_team': instance.homeTeam,
      'away_team': instance.awayTeam,
      'ft_home': instance.ftHome,
      'ft_away': instance.ftAway,
      'status': instance.status,
      'live_minute': instance.liveMinute,
      'result_code': instance.resultCode,
      'is_neutral': instance.isNeutral,
      'data_source': instance.dataSource,
      'source_url': instance.sourceUrl,
      'notes': instance.notes,
      'home_logo_url': instance.homeLogoUrl,
      'away_logo_url': instance.awayLogoUrl,
    };
