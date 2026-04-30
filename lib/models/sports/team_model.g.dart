// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeamModelImpl _$$TeamModelImplFromJson(Map<String, dynamic> json) =>
    _$TeamModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String?,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
      teamType: json['team_type'] as String? ?? 'club',
      description: json['description'] as String?,
      leagueName: json['league_name'] as String?,
      region: json['region'] as String?,
      competitionIds:
          (json['competition_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      aliases:
          (json['aliases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      searchTerms:
          (json['search_terms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      logoUrl: json['logo_url'] as String?,
      crestUrl: json['crest_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPopularPick: json['is_popular_pick'] as bool? ?? false,
      popularPickRank: (json['popular_pick_rank'] as num?)?.toInt(),
      fanCount: (json['fan_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$TeamModelImplToJson(_$TeamModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'short_name': instance.shortName,
      'country': instance.country,
      'country_code': instance.countryCode,
      'team_type': instance.teamType,
      'description': instance.description,
      'league_name': instance.leagueName,
      'region': instance.region,
      'competition_ids': instance.competitionIds,
      'aliases': instance.aliases,
      'search_terms': instance.searchTerms,
      'logo_url': instance.logoUrl,
      'crest_url': instance.crestUrl,
      'cover_image_url': instance.coverImageUrl,
      'is_active': instance.isActive,
      'is_featured': instance.isFeatured,
      'is_popular_pick': instance.isPopularPick,
      'popular_pick_rank': instance.popularPickRank,
      'fan_count': instance.fanCount,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
