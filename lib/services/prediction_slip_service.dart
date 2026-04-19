import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logging/app_logger.dart';
import '../main.dart' show supabaseInitialized;
import '../models/prediction_slip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/prediction_slip_provider.dart';

class PredictionSlipService {
  const PredictionSlipService(this._client);

  final SupabaseClient? _client;

  Future<String> submitSlip({
    required List<PredictionSelection> selections,
    int stake = 0,
  }) async {
    if (!supabaseInitialized || _client == null) {
      throw StateError('Supabase not initialized');
    }

    final client = _client;

    if (client.auth.currentUser == null) {
      throw StateError('Not authenticated');
    }

    if (selections.isEmpty) {
      throw ArgumentError('At least one selection is required');
    }

    final payload = selections
        .map(
          (selection) => {
            'match_id': selection.match.id,
            'match_name':
                '${selection.match.homeTeam} vs ${selection.match.awayTeam}',
            'market': selection.market,
            'selection': selection.selection,
            'potential_earn_fet': selection.projectedEarnForStake(stake),
          },
        )
        .toList();

    final result = await client.rpc(
      'submit_prediction_slip',
      params: {'p_selections': payload},
    );

    return result.toString();
  }

  Future<List<PredictionSlipModel>> getMySlips({int limit = 20}) async {
    if (!supabaseInitialized || _client == null) return const [];

    final client = _client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];

    final data = await client
        .from('prediction_slips')
        .select()
        .eq('user_id', userId)
        .order('submitted_at', ascending: false)
        .limit(limit);

    return (data as List)
        .map((row) => PredictionSlipModel.fromJson(row))
        .toList();
  }
}

final predictionSlipServiceProvider = Provider<PredictionSlipService>((ref) {
  final client = supabaseInitialized ? Supabase.instance.client : null;
  return PredictionSlipService(client);
});

final myPredictionSlipsProvider =
    FutureProvider.autoDispose<List<PredictionSlipModel>>((ref) async {
      ref.watch(authStateProvider);

      try {
        return ref.watch(predictionSlipServiceProvider).getMySlips();
      } on PostgrestException catch (error) {
        AppLogger.d(
          '[FANZONE] Failed to load prediction slips: ${error.message}',
        );
        rethrow;
      } catch (error) {
        AppLogger.d('Failed to load prediction slips: $error');
        rethrow;
      }
    });
