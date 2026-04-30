// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'featured_event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeaturedEventModelImpl _$$FeaturedEventModelImplFromJson(
  Map<String, dynamic> json,
) => _$FeaturedEventModelImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  shortName: json['short_name'] as String,
  eventTag: json['event_tag'] as String,
  region: json['region'] as String? ?? 'global',
  competitionId: json['competition_id'] as String?,
  startDate: DateTime.parse(json['start_date'] as String),
  endDate: DateTime.parse(json['end_date'] as String),
  isActive: json['is_active'] as bool? ?? true,
  bannerColor: json['banner_color'] as String?,
  description: json['description'] as String?,
  logoUrl: json['logo_url'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$FeaturedEventModelImplToJson(
  _$FeaturedEventModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'short_name': instance.shortName,
  'event_tag': instance.eventTag,
  'region': instance.region,
  'competition_id': instance.competitionId,
  'start_date': instance.startDate.toIso8601String(),
  'end_date': instance.endDate.toIso8601String(),
  'is_active': instance.isActive,
  'banner_color': instance.bannerColor,
  'description': instance.description,
  'logo_url': instance.logoUrl,
  'created_at': instance.createdAt?.toIso8601String(),
};
