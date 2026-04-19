// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MatchModelImpl _$$MatchModelImplFromJson(Map<String, dynamic> json) =>
    _$MatchModelImpl(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      season: json['season'] as String,
      round: json['round'] as String?,
      matchGroup: json['match_group'] as String?,
      date: DateTime.parse(json['date'] as String),
      kickoffTime: json['kickoff_time'] as String?,
      homeTeamId: json['home_team_id'] as String?,
      awayTeamId: json['away_team_id'] as String?,
      homeTeam: json['home_team'] as String,
      awayTeam: json['away_team'] as String,
      ftHome: (json['ft_home'] as num?)?.toInt(),
      ftAway: (json['ft_away'] as num?)?.toInt(),
      htHome: (json['ht_home'] as num?)?.toInt(),
      htAway: (json['ht_away'] as num?)?.toInt(),
      etHome: (json['et_home'] as num?)?.toInt(),
      etAway: (json['et_away'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'upcoming',
      venue: json['venue'] as String?,
      dataSource: json['data_source'] as String,
      sourceUrl: json['source_url'] as String?,
      homeLogoUrl: json['home_logo_url'] as String?,
      awayLogoUrl: json['away_logo_url'] as String?,
    );

Map<String, dynamic> _$$MatchModelImplToJson(_$MatchModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'competition_id': instance.competitionId,
      'season': instance.season,
      'round': instance.round,
      'match_group': instance.matchGroup,
      'date': instance.date.toIso8601String(),
      'kickoff_time': instance.kickoffTime,
      'home_team_id': instance.homeTeamId,
      'away_team_id': instance.awayTeamId,
      'home_team': instance.homeTeam,
      'away_team': instance.awayTeam,
      'ft_home': instance.ftHome,
      'ft_away': instance.ftAway,
      'ht_home': instance.htHome,
      'ht_away': instance.htAway,
      'et_home': instance.etHome,
      'et_away': instance.etAway,
      'status': instance.status,
      'venue': instance.venue,
      'data_source': instance.dataSource,
      'source_url': instance.sourceUrl,
      'home_logo_url': instance.homeLogoUrl,
      'away_logo_url': instance.awayLogoUrl,
    };
