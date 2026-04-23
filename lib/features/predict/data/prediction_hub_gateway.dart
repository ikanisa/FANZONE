import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/match_model.dart';
import '../../../models/prediction_engine_output_model.dart';
import '../../../models/team_form_feature_model.dart';
import '../../../models/user_prediction_model.dart';

class PredictionSubmissionRequest {
  const PredictionSubmissionRequest({
    required this.matchId,
    this.predictedResultCode,
    this.predictedOver25,
    this.predictedBtts,
    this.predictedHomeGoals,
    this.predictedAwayGoals,
  });

  final String matchId;
  final String? predictedResultCode;
  final bool? predictedOver25;
  final bool? predictedBtts;
  final int? predictedHomeGoals;
  final int? predictedAwayGoals;
}

abstract interface class PredictionHubGateway {
  Future<PredictionEngineOutputModel?> getEngineOutput(String matchId);

  Future<List<TeamFormFeatureModel>> getMatchFormFeatures(String matchId);

  Future<List<UserPredictionModel>> getMyPredictions(
    String userId, {
    int limit,
  });

  Future<UserPredictionModel?> getMyPredictionForMatch(
    String userId,
    String matchId,
  );

  Future<Map<String, MatchModel>> getMatchesByIds(Iterable<String> matchIds);

  Future<void> submitPrediction(PredictionSubmissionRequest request);
}

class SupabasePredictionHubGateway implements PredictionHubGateway {
  SupabasePredictionHubGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<PredictionEngineOutputModel?> getEngineOutput(String matchId) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('predictions_engine_outputs')
          .select()
          .eq('match_id', matchId)
          .maybeSingle();
      if (row == null) return null;
      return PredictionEngineOutputModel.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (error) {
      AppLogger.d('Failed to load engine output for $matchId: $error');
      return null;
    }
  }

  @override
  Future<List<TeamFormFeatureModel>> getMatchFormFeatures(String matchId) async {
    final client = _connection.client;
    if (client == null) return const <TeamFormFeatureModel>[];

    try {
      final rows = await client
          .from('team_form_features')
          .select()
          .eq('match_id', matchId);

      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => TeamFormFeatureModel.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load form features for $matchId: $error');
      return const <TeamFormFeatureModel>[];
    }
  }

  @override
  Future<List<UserPredictionModel>> getMyPredictions(
    String userId, {
    int limit = 100,
  }) async {
    final client = _connection.client;
    if (client == null) return const <UserPredictionModel>[];

    try {
      final rows = await client
          .from('user_predictions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                UserPredictionModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load user predictions: $error');
      return const <UserPredictionModel>[];
    }
  }

  @override
  Future<UserPredictionModel?> getMyPredictionForMatch(
    String userId,
    String matchId,
  ) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('user_predictions')
          .select()
          .eq('user_id', userId)
          .eq('match_id', matchId)
          .maybeSingle();
      if (row == null) return null;
      return UserPredictionModel.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (error) {
      AppLogger.d('Failed to load prediction for $matchId: $error');
      return null;
    }
  }

  @override
  Future<Map<String, MatchModel>> getMatchesByIds(Iterable<String> matchIds) async {
    final client = _connection.client;
    if (client == null) return const <String, MatchModel>{};

    final ids = matchIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <String, MatchModel>{};

    try {
      final rows = await client.from('app_matches').select().inFilter('id', ids);
      final matchMap = <String, MatchModel>{};
      for (final row in (rows as List).whereType<Map>()) {
        final data = Map<String, dynamic>.from(row);
        final match = MatchModel.fromJson(data);
        matchMap[match.id] = match;
      }
      return matchMap;
    } catch (error) {
      AppLogger.d('Failed to resolve prediction matches: $error');
      return const <String, MatchModel>{};
    }
  }

  @override
  Future<void> submitPrediction(PredictionSubmissionRequest request) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Supabase not connected');
    }

    final response = await client.rpc(
      'submit_user_prediction',
      params: {
        'p_match_id': request.matchId,
        'p_predicted_result_code': request.predictedResultCode,
        'p_predicted_over25': request.predictedOver25,
        'p_predicted_btts': request.predictedBtts,
        'p_predicted_home_goals': request.predictedHomeGoals,
        'p_predicted_away_goals': request.predictedAwayGoals,
      },
    );

    if (response == null) {
      throw StateError('Prediction submission returned no payload');
    }
  }
}
