import 'package:injectable/injectable.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/prediction_slip_model.dart';
import 'predict_gateway_models.dart';
import 'predict_gateway_shared.dart';

abstract interface class PredictionSlipGateway {
  Future<String> submitPredictionSlip(PredictionSlipSubmissionDto request);

  Future<List<PredictionSlipModel>> getMyPredictionSlips(
    String userId, {
    int limit,
  });
}

@LazySingleton(as: PredictionSlipGateway)
class SupabasePredictionSlipGateway implements PredictionSlipGateway {
  SupabasePredictionSlipGateway(this._connection);

  final SupabaseConnection _connection;
  final Map<String, List<PredictionSlipModel>> _localSlipsByUser =
      <String, List<PredictionSlipModel>>{};

  @override
  Future<String> submitPredictionSlip(
    PredictionSlipSubmissionDto request,
  ) async {
    final client = _connection.client;
    if (client == null) {
      throwPredictUnavailable('Prediction slip submission');
    }

    try {
      final response = await client.rpc(
        'submit_prediction_slip',
        params: {
          'p_selections': request.selections
              .map(
                (selection) => {
                  'match_id': selection.match.id,
                  'match_name':
                      '${selection.match.homeTeam} vs ${selection.match.awayTeam}',
                  'market': selection.market,
                  'selection': selection.selection,
                  'potential_earn_fet': selection.projectedEarnForStake(
                    request.stake,
                  ),
                },
              )
              .toList(growable: false),
        },
      );

      if (response is String) return response;
      if (response is Map && response['slip_id'] != null) {
        return response['slip_id'].toString();
      }
    } catch (error) {
      AppLogger.d('Failed to submit prediction slip remotely: $error');
      rethrow;
    }

    throw StateError('Prediction slip submission did not return a slip id.');
  }

  @override
  Future<List<PredictionSlipModel>> getMyPredictionSlips(
    String userId, {
    int limit = 20,
  }) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('prediction_slips')
            .select()
            .eq('user_id', userId)
            .order('submitted_at', ascending: false)
            .limit(limit);
        final slips = (rows as List)
            .whereType<Map>()
            .map(
              (row) =>
                  PredictionSlipModel.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
        if (slips.isNotEmpty) return slips;
      } catch (error) {
        AppLogger.d('Failed to load prediction slips: $error');
      }
    }

    if (!allowPredictSeedFallback) return const <PredictionSlipModel>[];
    final slips = _localSlipsByUser[userId] ?? const <PredictionSlipModel>[];
    return slips.take(limit).toList(growable: false);
  }
}
