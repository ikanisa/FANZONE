// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_supporter_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeamSupporterModelImpl _$$TeamSupporterModelImplFromJson(
  Map<String, dynamic> json,
) => _$TeamSupporterModelImpl(
  id: json['id'] as String,
  teamId: json['team_id'] as String,
  userId: json['user_id'] as String,
  anonymousFanId: json['anonymous_fan_id'] as String,
  joinedAt: DateTime.parse(json['joined_at'] as String),
  isActive: json['is_active'] as bool? ?? true,
);

Map<String, dynamic> _$$TeamSupporterModelImplToJson(
  _$TeamSupporterModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'team_id': instance.teamId,
  'user_id': instance.userId,
  'anonymous_fan_id': instance.anonymousFanId,
  'joined_at': instance.joinedAt.toIso8601String(),
  'is_active': instance.isActive,
};

_$AnonymousFanRecordImpl _$$AnonymousFanRecordImplFromJson(
  Map<String, dynamic> json,
) => _$AnonymousFanRecordImpl(
  anonymousFanId: json['anonymous_fan_id'] as String,
  joinedAt: DateTime.parse(json['joined_at'] as String),
);

Map<String, dynamic> _$$AnonymousFanRecordImplToJson(
  _$AnonymousFanRecordImpl instance,
) => <String, dynamic>{
  'anonymous_fan_id': instance.anonymousFanId,
  'joined_at': instance.joinedAt.toIso8601String(),
};
