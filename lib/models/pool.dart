import 'package:freezed_annotation/freezed_annotation.dart';

part 'pool.freezed.dart';
part 'pool.g.dart';

@freezed
class ScorePool with _$ScorePool {
  const factory ScorePool({
    required String id,
    required String matchId,
    required String matchName,
    required String creatorId,
    required String creatorName,
    required String creatorPrediction,
    required int stake,
    required int totalPool,
    required int participantsCount,
    required String status, // 'open' | 'locked' | 'settled' | 'void'
    required DateTime lockAt,
  }) = _ScorePool;

  factory ScorePool.fromJson(Map<String, dynamic> json) =>
      _$ScorePoolFromJson(json);
}

@freezed
class PoolEntry with _$PoolEntry {
  const factory PoolEntry({
    required String id,
    required String poolId,
    required String userId,
    required String userName,
    required int predictedHomeScore,
    required int predictedAwayScore,
    required int stake,
    required String status, // 'active' | 'winner' | 'loser' | 'refunded'
    required int payout,
  }) = _PoolEntry;

  factory PoolEntry.fromJson(Map<String, dynamic> json) =>
      _$PoolEntryFromJson(json);
}
