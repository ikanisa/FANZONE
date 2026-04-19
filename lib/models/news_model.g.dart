// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NewsModelImpl _$$NewsModelImplFromJson(Map<String, dynamic> json) =>
    _$NewsModelImpl(
      id: json['id'] as String,
      source: json['source'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      imageUrl: json['image_url'] as String?,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
      fetchedAt: json['fetched_at'] == null
          ? null
          : DateTime.parse(json['fetched_at'] as String),
    );

Map<String, dynamic> _$$NewsModelImplToJson(_$NewsModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'source': instance.source,
      'title': instance.title,
      'url': instance.url,
      'image_url': instance.imageUrl,
      'published_at': instance.publishedAt?.toIso8601String(),
      'fetched_at': instance.fetchedAt?.toIso8601String(),
    };
