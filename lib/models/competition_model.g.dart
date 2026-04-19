// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'competition_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CompetitionModelImpl _$$CompetitionModelImplFromJson(
  Map<String, dynamic> json,
) => _$CompetitionModelImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  shortName: json['short_name'] as String,
  country: json['country'] as String,
  tier: (json['tier'] as num?)?.toInt() ?? 1,
  dataSource: json['data_source'] as String,
  sourceFile: json['source_file'] as String?,
  seasons:
      (json['seasons'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  teamCount: (json['team_count'] as num?)?.toInt(),
  logoUrl: json['logo_url'] as String?,
  region: json['region'] as String?,
  competitionType: json['competition_type'] as String?,
  isFeatured: json['is_featured'] as bool? ?? false,
  eventTag: json['event_tag'] as String?,
  startDate: json['start_date'] == null
      ? null
      : DateTime.parse(json['start_date'] as String),
  endDate: json['end_date'] == null
      ? null
      : DateTime.parse(json['end_date'] as String),
);

Map<String, dynamic> _$$CompetitionModelImplToJson(
  _$CompetitionModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'short_name': instance.shortName,
  'country': instance.country,
  'tier': instance.tier,
  'data_source': instance.dataSource,
  'source_file': instance.sourceFile,
  'seasons': instance.seasons,
  'team_count': instance.teamCount,
  'logo_url': instance.logoUrl,
  'region': instance.region,
  'competition_type': instance.competitionType,
  'is_featured': instance.isFeatured,
  'event_tag': instance.eventTag,
  'start_date': instance.startDate?.toIso8601String(),
  'end_date': instance.endDate?.toIso8601String(),
};
