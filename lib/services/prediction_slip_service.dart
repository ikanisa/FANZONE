import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/failures.dart';
import '../core/logging/app_logger.dart';
import '../features/predict/data/predict_gateway.dart';
import '../models/prediction_slip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/prediction_slip_provider.dart';
import 'product_analytics_service.dart';

class PredictionSlipService {
  const PredictionSlipService(this._gateway);

  final PredictGateway _gateway;

  Future<String> submitSlip({
    required List<PredictionSelection> selections,
    int stake = 0,
  }) async {
    if (selections.isEmpty) {
      throw const ValidationFailure(
        message: 'At least one selection is required',
        code: 'empty_selections',
      );
    }

    final slipId = await _gateway.submitPredictionSlip(
      PredictionSlipSubmissionDto(selections: selections, stake: stake),
    );

    // Track each prediction in the slip for funnel analytics
    for (final selection in selections) {
      ProductAnalytics.predictionSubmitted(
        matchId: selection.match.id,
        market: selection.market,
        selection: selection.selection,
      );
    }

    return slipId;
  }

  Future<List<PredictionSlipModel>> getMySlips({
    required String userId,
    int limit = 20,
  }) {
    return _gateway.getMyPredictionSlips(userId, limit: limit);
  }
}

final predictionSlipServiceProvider = Provider<PredictionSlipService>((ref) {
  return PredictionSlipService(getIt<PredictGateway>());
});

final myPredictionSlipsProvider =
    FutureProvider.autoDispose<List<PredictionSlipModel>>((ref) async {
      ref.watch(authStateProvider);

      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId == null) return const [];

      try {
        return ref.watch(predictionSlipServiceProvider).getMySlips(userId: userId);
      } catch (error, stack) {
        final failure = mapExceptionToFailure(error, stack);
        AppLogger.w('Failed to load prediction slips: ${failure.message}');
        throw failure;
      }
    });
