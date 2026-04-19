// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'global_challenge_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GlobalChallengeModelImpl _$$GlobalChallengeModelImplFromJson(
  Map<String, dynamic> json,
) => _$GlobalChallengeModelImpl(
  id: json['id'] as String,
  eventTag: json['event_tag'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  matchIds:
      (json['match_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  entryFeeFet: (json['entry_fee_fet'] as num?)?.toInt() ?? 0,
  prizePoolFet: (json['prize_pool_fet'] as num?)?.toInt() ?? 0,
  maxParticipants: (json['max_participants'] as num?)?.toInt(),
  currentParticipants: (json['current_participants'] as num?)?.toInt() ?? 0,
  region: json['region'] as String? ?? 'global',
  status: json['status'] as String? ?? 'open',
  startAt: json['start_at'] == null
      ? null
      : DateTime.parse(json['start_at'] as String),
  endAt: json['end_at'] == null
      ? null
      : DateTime.parse(json['end_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$GlobalChallengeModelImplToJson(
  _$GlobalChallengeModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'event_tag': instance.eventTag,
  'name': instance.name,
  'description': instance.description,
  'match_ids': instance.matchIds,
  'entry_fee_fet': instance.entryFeeFet,
  'prize_pool_fet': instance.prizePoolFet,
  'max_participants': instance.maxParticipants,
  'current_participants': instance.currentParticipants,
  'region': instance.region,
  'status': instance.status,
  'start_at': instance.startAt?.toIso8601String(),
  'end_at': instance.endAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
};
