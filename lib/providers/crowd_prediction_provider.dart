import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../core/logging/app_logger.dart';

/// Crowd prediction distribution for a given match.
///
/// Aggregates all `prediction_challenge_entries` for a match and computes
/// the percentage breakdown of Home / Draw / Away predictions.
final crowdPredictionProvider = FutureProvider.family
    .autoDispose<CrowdPrediction?, String>((ref, matchId) async {
      final connection = ref.read(supabaseConnectionProvider);
      final client = connection.client;
      if (client == null) return null;

      try {
        // Aggregate predictions from all entries for pools linked to this match.
        // We count predictions as: home win = homeScore > awayScore,
        // away win = awayScore > homeScore, draw = homeScore == awayScore.
        final rows = await client
            .from('prediction_challenge_entries')
            .select('predicted_home_score, predicted_away_score')
            .eq('match_id', matchId);

        final entries = rows as List;
        if (entries.isEmpty) {
          // Try alternative: join through prediction_challenges
          return await _fetchViaPool(client, matchId);
        }

        return _computeDistribution(entries);
      } catch (error) {
        AppLogger.d('Crowd prediction query failed, trying via pool: $error');
        try {
          return await _fetchViaPool(
            ref.read(supabaseConnectionProvider).client!,
            matchId,
          );
        } catch (_) {
          return null;
        }
      }
    });

/// Alternative: Query entries through prediction_challenges table.
Future<CrowdPrediction?> _fetchViaPool(dynamic client, String matchId) async {
  try {
    // First find pool IDs for this match
    final pools = await client
        .from('prediction_challenges')
        .select('id')
        .eq('match_id', matchId);

    final poolIds = (pools as List)
        .whereType<Map>()
        .map((row) => row['id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toList();

    if (poolIds.isEmpty) return null;

    final entries = await client
        .from('prediction_challenge_entries')
        .select('predicted_home_score, predicted_away_score')
        .inFilter('challenge_id', poolIds);

    if ((entries as List).isEmpty) return null;
    return _computeDistribution(entries);
  } catch (error) {
    AppLogger.d('Pool-based crowd prediction also failed: $error');
    return null;
  }
}

CrowdPrediction _computeDistribution(List<dynamic> entries) {
  var home = 0;
  var draw = 0;
  var away = 0;

  for (final entry in entries) {
    if (entry is! Map) continue;
    final hs = (entry['predicted_home_score'] as num?)?.toInt() ?? 0;
    final as_ = (entry['predicted_away_score'] as num?)?.toInt() ?? 0;

    if (hs > as_) {
      home++;
    } else if (hs < as_) {
      away++;
    } else {
      draw++;
    }
  }

  final total = home + draw + away;
  if (total == 0) {
    return const CrowdPrediction(home: 34, draw: 33, away: 33, total: 0);
  }

  return CrowdPrediction(
    home: (home / total * 100).round().clamp(1, 98),
    draw: (draw / total * 100).round().clamp(1, 98),
    away: (away / total * 100).round().clamp(1, 98),
    total: total,
  );
}

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
