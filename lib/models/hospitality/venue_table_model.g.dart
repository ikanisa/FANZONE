// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue_table_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VenueTableModelImpl _$$VenueTableModelImplFromJson(
  Map<String, dynamic> json,
) => _$VenueTableModelImpl(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  tableNumber: json['table_number'] as String,
  qrCodeUrl: json['qr_code_url'] as String?,
  deepLinkUri: json['deep_link_uri'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$VenueTableModelImplToJson(
  _$VenueTableModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'venue_id': instance.venueId,
  'table_number': instance.tableNumber,
  'qr_code_url': instance.qrCodeUrl,
  'deep_link_uri': instance.deepLinkUri,
  'is_active': instance.isActive,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
