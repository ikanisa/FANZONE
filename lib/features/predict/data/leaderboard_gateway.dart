
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import 'predict_gateway_models.dart';
import 'predict_gateway_shared.dart';

abstract interface class LeaderboardGateway {
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard();

  Future<int?> getUserRank(String userId);
}

class SupabaseLeaderboardGateway implements LeaderboardGateway {
  SupabaseLeaderboardGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard() async {
    final client = _connection.client;
    if (client == null) {
      return _seededLeaderboard();
    }

    try {
      final rows = await client
          .from('public_leaderboard')
          .select('display_name, total_fet')
          .order('total_fet', ascending: false)
          .limit(50);

      final leaderboard = <GlobalLeaderboardEntryDto>[];
      for (var index = 0; index < (rows as List).length; index += 1) {
        final row = Map<String, dynamic>.from(rows[index] as Map);
        leaderboard.add(
          GlobalLeaderboardEntryDto(
            rank: index + 1,
            name: row['display_name']?.toString() ?? 'Fan',
            fet: (row['total_fet'] as num?)?.toInt() ?? 0,
            level: 1,
          ),
        );
      }

      return leaderboard.map((row) => row.toJson()).toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load global leaderboard: $error');
      return _seededLeaderboard();
    }
  }

  @override
  Future<int?> getUserRank(String userId) async {
    final leaderboard = await getGlobalLeaderboard();
    for (final row in leaderboard) {
      if (row['user_id']?.toString() == userId) {
        return (row['rank'] as num?)?.toInt();
      }
    }

    final client = _connection.client;
    if (client == null) return allowPredictSeedFallback ? 4 : null;

    try {
      final rows = await client
          .from('public_leaderboard')
          .select('user_id')
          .order('total_fet', ascending: false);
      for (var index = 0; index < (rows as List).length; index += 1) {
        final row = rows[index] as Map;
        if (row['user_id']?.toString() == userId) {
          return index + 1;
        }
      }
      return null;
    } catch (error) {
      AppLogger.d('Failed to resolve user rank: $error');
      return null;
    }
  }

  List<Map<String, dynamic>> _seededLeaderboard() {
    if (!allowPredictSeedFallback) return const <Map<String, dynamic>>[];
    return fallbackLeaderboard
        .map((row) => row.toJson())
        .toList(growable: false);
  }
}
