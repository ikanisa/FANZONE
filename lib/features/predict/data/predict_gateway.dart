import 'package:injectable/injectable.dart';

import '../../../models/daily_challenge_model.dart';
import '../../../models/pool.dart';
import '../../../models/prediction_slip_model.dart';
import 'daily_challenge_gateway.dart';
import 'leaderboard_gateway.dart';
import 'prediction_pool_gateway.dart';
import 'prediction_slip_gateway.dart';
import 'predict_gateway_models.dart';

export 'daily_challenge_gateway.dart';
export 'leaderboard_gateway.dart';
export 'prediction_pool_gateway.dart';
export 'prediction_slip_gateway.dart';
export 'predict_gateway_models.dart';

abstract interface class PredictGateway
    implements
        PredictionPoolGateway,
        LeaderboardGateway,
        DailyChallengeGateway,
        PredictionSlipGateway {}

@LazySingleton(as: PredictGateway)
class SupabasePredictGateway implements PredictGateway {
  SupabasePredictGateway(
    this._pools,
    this._leaderboard,
    this._dailyChallenge,
    this._slips,
  );

  final PredictionPoolGateway _pools;
  final LeaderboardGateway _leaderboard;
  final DailyChallengeGateway _dailyChallenge;
  final PredictionSlipGateway _slips;

  @override
  Future<void> createPool(PoolCreateRequestDto request) {
    return _pools.createPool(request);
  }

  @override
  Future<List<DailyChallengeEntry>> getDailyChallengeHistory(String userId) {
    return _dailyChallenge.getDailyChallengeHistory(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard() {
    return _leaderboard.getGlobalLeaderboard();
  }

  @override
  Future<List<PoolEntry>> getMyEntries(String userId) {
    return _pools.getMyEntries(userId);
  }

  @override
  Future<DailyChallengeEntry?> getMyDailyEntry({
    required String challengeId,
    required String userId,
  }) {
    return _dailyChallenge.getMyDailyEntry(
      challengeId: challengeId,
      userId: userId,
    );
  }

  @override
  Future<List<PredictionSlipModel>> getMyPredictionSlips(
    String userId, {
    int limit = 20,
  }) {
    return _slips.getMyPredictionSlips(userId, limit: limit);
  }

  @override
  Future<ScorePool?> getPoolDetail(String id) {
    return _pools.getPoolDetail(id);
  }

  @override
  Future<List<ScorePool>> getPools() {
    return _pools.getPools();
  }

  @override
  Future<DailyChallenge?> getTodaysDailyChallenge() {
    return _dailyChallenge.getTodaysDailyChallenge();
  }

  @override
  Future<int?> getUserRank(String userId) {
    return _leaderboard.getUserRank(userId);
  }

  @override
  Future<void> joinPool(PoolJoinRequestDto request) {
    return _pools.joinPool(request);
  }

  @override
  Future<String> submitPredictionSlip(PredictionSlipSubmissionDto request) {
    return _slips.submitPredictionSlip(request);
  }

  @override
  Future<void> submitDailyPrediction({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) {
    return _dailyChallenge.submitDailyPrediction(
      challengeId: challengeId,
      homeScore: homeScore,
      awayScore: awayScore,
    );
  }
}
