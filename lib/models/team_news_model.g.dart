// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_news_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeamNewsModelImpl _$$TeamNewsModelImplFromJson(Map<String, dynamic> json) =>
    _$TeamNewsModelImpl(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      content: json['content'] as String?,
      category: json['category'] as String? ?? 'general',
      sourceUrl: json['source_url'] as String?,
      sourceName: json['source_name'] as String?,
      imageUrl: json['image_url'] as String?,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
      status: json['status'] as String,
      isAiCurated: json['is_ai_curated'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$TeamNewsModelImplToJson(_$TeamNewsModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'team_id': instance.teamId,
      'title': instance.title,
      'summary': instance.summary,
      'content': instance.content,
      'category': instance.category,
      'source_url': instance.sourceUrl,
      'source_name': instance.sourceName,
      'image_url': instance.imageUrl,
      'published_at': instance.publishedAt?.toIso8601String(),
      'status': instance.status,
      'is_ai_curated': instance.isAiCurated,
      'metadata': instance.metadata,
      'created_at': instance.createdAt?.toIso8601String(),
    };
