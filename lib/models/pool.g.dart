// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pool.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScorePoolImpl _$$ScorePoolImplFromJson(Map<String, dynamic> json) =>
    _$ScorePoolImpl(
      id: json['id'] as String,
      matchId: json['matchId'] as String,
      matchName: json['matchName'] as String,
      creatorId: json['creatorId'] as String,
      creatorName: json['creatorName'] as String,
      creatorPrediction: json['creatorPrediction'] as String,
      stake: (json['stake'] as num).toInt(),
      totalPool: (json['totalPool'] as num).toInt(),
      participantsCount: (json['participantsCount'] as num).toInt(),
      status: json['status'] as String,
      lockAt: DateTime.parse(json['lockAt'] as String),
    );

Map<String, dynamic> _$$ScorePoolImplToJson(_$ScorePoolImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'matchId': instance.matchId,
      'matchName': instance.matchName,
      'creatorId': instance.creatorId,
      'creatorName': instance.creatorName,
      'creatorPrediction': instance.creatorPrediction,
      'stake': instance.stake,
      'totalPool': instance.totalPool,
      'participantsCount': instance.participantsCount,
      'status': instance.status,
      'lockAt': instance.lockAt.toIso8601String(),
    };

_$PoolEntryImpl _$$PoolEntryImplFromJson(Map<String, dynamic> json) =>
    _$PoolEntryImpl(
      id: json['id'] as String,
      poolId: json['poolId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      predictedHomeScore: (json['predictedHomeScore'] as num).toInt(),
      predictedAwayScore: (json['predictedAwayScore'] as num).toInt(),
      stake: (json['stake'] as num).toInt(),
      status: json['status'] as String,
      payout: (json['payout'] as num).toInt(),
    );

Map<String, dynamic> _$$PoolEntryImplToJson(_$PoolEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'poolId': instance.poolId,
      'userId': instance.userId,
      'userName': instance.userName,
      'predictedHomeScore': instance.predictedHomeScore,
      'predictedAwayScore': instance.predictedAwayScore,
      'stake': instance.stake,
      'status': instance.status,
      'payout': instance.payout,
    };
