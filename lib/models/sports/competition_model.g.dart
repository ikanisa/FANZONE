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
  shortName: json['short_name'] as String? ?? '',
  country: json['country'] as String? ?? '',
  tier: (json['tier'] as num?)?.toInt() ?? 1,
  competitionType: json['competition_type'] as String?,
  isFeatured: json['is_featured'] as bool? ?? false,
  isInternational: json['is_international'] as bool? ?? false,
  isActive: json['is_active'] as bool? ?? true,
  currentSeasonId: json['current_season_id'] as String?,
  currentSeasonLabel: json['current_season_label'] as String?,
  futureMatchCount: (json['future_match_count'] as num?)?.toInt() ?? 0,
  catalogRank: (json['catalog_rank'] as num?)?.toInt(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$CompetitionModelImplToJson(
  _$CompetitionModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'short_name': instance.shortName,
  'country': instance.country,
  'tier': instance.tier,
  'competition_type': instance.competitionType,
  'is_featured': instance.isFeatured,
  'is_international': instance.isInternational,
  'is_active': instance.isActive,
  'current_season_id': instance.currentSeasonId,
  'current_season_label': instance.currentSeasonLabel,
  'future_match_count': instance.futureMatchCount,
  'catalog_rank': instance.catalogRank,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
