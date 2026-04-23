import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../features/predict/data/prediction_hub_gateway.dart';
import '../models/match_model.dart';
import '../models/prediction_engine_output_model.dart';
import '../models/team_form_feature_model.dart';
import '../models/user_prediction_model.dart';
import '../providers/auth_provider.dart';

class PredictionService {
  const PredictionService(this._gateway);

  final PredictionHubGateway _gateway;

  Future<PredictionEngineOutputModel?> getEngineOutput(String matchId) {
    return _gateway.getEngineOutput(matchId);
  }

  Future<List<TeamFormFeatureModel>> getMatchFormFeatures(String matchId) {
    return _gateway.getMatchFormFeatures(matchId);
  }

  Future<List<UserPredictionModel>> getMyPredictions(
    String userId, {
    int limit = 100,
  }) {
    return _gateway.getMyPredictions(userId, limit: limit);
  }

  Future<UserPredictionModel?> getMyPredictionForMatch(
    String userId,
    String matchId,
  ) {
    return _gateway.getMyPredictionForMatch(userId, matchId);
  }

  Future<Map<String, MatchModel>> getMatchesByIds(Iterable<String> matchIds) {
    return _gateway.getMatchesByIds(matchIds);
  }

  Future<void> submitPrediction(PredictionSubmissionRequest request) {
    return _gateway.submitPrediction(request);
  }
}

final predictionServiceProvider = Provider<PredictionService>((ref) {
  return PredictionService(
    SupabasePredictionHubGateway(ref.read(supabaseConnectionProvider)),
  );
});

final predictionEngineOutputProvider = FutureProvider.family
    .autoDispose<PredictionEngineOutputModel?, String>((ref, matchId) async {
      return ref.read(predictionServiceProvider).getEngineOutput(matchId);
    });

final matchFormFeaturesProvider = FutureProvider.family
    .autoDispose<List<TeamFormFeatureModel>, String>((ref, matchId) async {
      return ref.read(predictionServiceProvider).getMatchFormFeatures(matchId);
    });

final myPredictionsProvider =
    FutureProvider.autoDispose<List<UserPredictionModel>>((ref) async {
      ref.watch(authStateProvider);
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId == null) return const <UserPredictionModel>[];
      return ref.read(predictionServiceProvider).getMyPredictions(userId);
    });

final myPredictionForMatchProvider = FutureProvider.family
    .autoDispose<UserPredictionModel?, String>((ref, matchId) async {
      ref.watch(authStateProvider);
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId == null) return null;
      return ref
          .read(predictionServiceProvider)
          .getMyPredictionForMatch(userId, matchId);
    });

final predictionMatchLookupProvider = FutureProvider.family
    .autoDispose<Map<String, MatchModel>, String>((ref, key) async {
      final ids = key
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (ids.isEmpty) return const <String, MatchModel>{};
      return ref.read(predictionServiceProvider).getMatchesByIds(ids);
    });
