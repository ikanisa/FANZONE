import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../core/logging/app_logger.dart';

/// Crowd prediction distribution for a given match.
///
/// Reads the lean `match_prediction_consensus` view and normalizes the
/// percentage breakdown of Home / Draw / Away picks.
final crowdPredictionProvider = FutureProvider.family
    .autoDispose<CrowdPrediction?, String>((ref, matchId) async {
      final connection = ref.read(supabaseConnectionProvider);
      final client = connection.client;
      if (client == null) return null;

      try {
        final row = await client
            .from('match_prediction_consensus')
            .select()
            .eq('match_id', matchId)
            .maybeSingle();
        if (row == null) {
          return const CrowdPrediction(home: 34, draw: 33, away: 33, total: 0);
        }

        final data = Map<String, dynamic>.from(row as Map);
        return CrowdPrediction(
          home: (data['home_pct'] as num?)?.toInt() ?? 34,
          draw: (data['draw_pct'] as num?)?.toInt() ?? 33,
          away: (data['away_pct'] as num?)?.toInt() ?? 33,
          total: (data['total_predictions'] as num?)?.toInt() ?? 0,
        );
      } catch (error) {
        AppLogger.d('Crowd prediction query failed: $error');
        return null;
      }
    });

/// Crowd prediction distribution percentages.
class CrowdPrediction {
  const CrowdPrediction({
    required this.home,
    required this.draw,
    required this.away,
    required this.total,
  });

  final int home;
  final int draw;
  final int away;
  final int total;

  /// Normalized percentages that always sum to 100.
  (int, int, int) get normalized {
    if (total == 0) return (34, 33, 33);
    final sum = home + draw + away;
    if (sum == 100) return (home, draw, away);
    // Adjust the largest to absorb rounding error
    final diff = 100 - sum;
    if (home >= draw && home >= away) return (home + diff, draw, away);
    if (draw >= home && draw >= away) return (home, draw + diff, away);
    return (home, draw, away + diff);
  }
}
