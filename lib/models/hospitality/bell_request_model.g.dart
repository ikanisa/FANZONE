// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bell_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BellRequestModelImpl _$$BellRequestModelImplFromJson(
  Map<String, dynamic> json,
) => _$BellRequestModelImpl(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  tableId: json['table_id'] as String,
  userId: json['user_id'] as String,
  message: json['message'] as String?,
  acknowledgedAt: json['acknowledged_at'] == null
      ? null
      : DateTime.parse(json['acknowledged_at'] as String),
  acknowledgedBy: json['acknowledged_by'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$BellRequestModelImplToJson(
  _$BellRequestModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'venue_id': instance.venueId,
  'table_id': instance.tableId,
  'user_id': instance.userId,
  'message': instance.message,
  'acknowledged_at': instance.acknowledgedAt?.toIso8601String(),
  'acknowledged_by': instance.acknowledgedBy,
  'created_at': instance.createdAt?.toIso8601String(),
};
