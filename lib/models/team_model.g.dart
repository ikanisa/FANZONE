// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeamModelImpl _$$TeamModelImplFromJson(
  Map<String, dynamic> json,
) => _$TeamModelImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  shortName: json['short_name'] as String?,
  slug: json['slug'] as String?,
  country: json['country'] as String?,
  description: json['description'] as String?,
  leagueName: json['league_name'] as String?,
  competitionIds:
      (json['competition_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  aliases:
      (json['aliases'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  logoUrl: json['logo_url'] as String?,
  crestUrl: json['crest_url'] as String?,
  coverImageUrl: json['cover_image_url'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  isFeatured: json['is_featured'] as bool? ?? false,
  fetContributionsEnabled: json['fet_contributions_enabled'] as bool? ?? false,
  fiatContributionsEnabled:
      json['fiat_contributions_enabled'] as bool? ?? false,
  fiatContributionMode: json['fiat_contribution_mode'] as String?,
  fiatContributionLink: json['fiat_contribution_link'] as String?,
  fanCount: (json['fan_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$TeamModelImplToJson(_$TeamModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'short_name': instance.shortName,
      'slug': instance.slug,
      'country': instance.country,
      'description': instance.description,
      'league_name': instance.leagueName,
      'competition_ids': instance.competitionIds,
      'aliases': instance.aliases,
      'logo_url': instance.logoUrl,
      'crest_url': instance.crestUrl,
      'cover_image_url': instance.coverImageUrl,
      'is_active': instance.isActive,
      'is_featured': instance.isFeatured,
      'fet_contributions_enabled': instance.fetContributionsEnabled,
      'fiat_contributions_enabled': instance.fiatContributionsEnabled,
      'fiat_contribution_mode': instance.fiatContributionMode,
      'fiat_contribution_link': instance.fiatContributionLink,
      'fan_count': instance.fanCount,
    };
