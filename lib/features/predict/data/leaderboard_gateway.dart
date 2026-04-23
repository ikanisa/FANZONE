import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';

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
    if (client == null) return const <Map<String, dynamic>>[];

    try {
      final rows = await client
          .from('public_leaderboard')
          .select('display_name, total_fet')
          .order('total_fet', ascending: false)
          .limit(50);

      final leaderboard = <Map<String, dynamic>>[];
      for (var index = 0; index < (rows as List).length; index += 1) {
        final row = Map<String, dynamic>.from(rows[index] as Map);
        leaderboard.add(
          <String, dynamic>{
            'rank': index + 1,
            'name': row['display_name']?.toString() ?? 'Fan',
            'fet': (row['total_fet'] as num?)?.toInt() ?? 0,
            'level': 1,
          },
        );
      }

      return leaderboard;
    } catch (error) {
      AppLogger.d('Failed to load global leaderboard: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  @override
  Future<int?> getUserRank(String userId) async {
    final client = _connection.client;
    if (client == null) return null;

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
}
