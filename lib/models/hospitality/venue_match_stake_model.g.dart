// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue_match_stake_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VenueMatchStakeModelImpl _$$VenueMatchStakeModelImplFromJson(
  Map<String, dynamic> json,
) => _$VenueMatchStakeModelImpl(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  matchId: json['match_id'] as String,
  entryFeeFet: (json['entry_fee_fet'] as num).toInt(),
  totalPoolFet: (json['total_pool_fet'] as num).toInt(),
  status: $enumDecode(_$VenueStakeStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$VenueMatchStakeModelImplToJson(
  _$VenueMatchStakeModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'venue_id': instance.venueId,
  'match_id': instance.matchId,
  'entry_fee_fet': instance.entryFeeFet,
  'total_pool_fet': instance.totalPoolFet,
  'status': _$VenueStakeStatusEnumMap[instance.status]!,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};

const _$VenueStakeStatusEnumMap = {
  VenueStakeStatus.open: 'open',
  VenueStakeStatus.settled: 'settled',
  VenueStakeStatus.cancelled: 'cancelled',
};
