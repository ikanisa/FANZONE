
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/leaderboard_season_model.dart';
import 'engagement_gateway_shared.dart';

abstract interface class SeasonLeaderboardGateway {
  Future<List<LeaderboardSeason>> getActiveLeaderboardSeasons();

  Future<List<SeasonLeaderboardEntry>> getSeasonRankings(String seasonId);

  Future<SeasonLeaderboardEntry?> getUserSeasonEntry(
    String seasonId,
    String userId,
  );

  Future<List<LeaderboardSeason>> getCompletedSeasons();
}

class SupabaseSeasonLeaderboardGateway implements SeasonLeaderboardGateway {
  SupabaseSeasonLeaderboardGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<LeaderboardSeason>> getActiveLeaderboardSeasons() async {
    final client = _connection.client;
    if (client == null) return _fallbackActiveSeasons();

    try {
      final rows = await client
          .from('leaderboard_seasons')
          .select()
          .eq('status', 'active')
          .order('starts_at', ascending: false);
      final seasons = (rows as List)
          .whereType<Map>()
          .map(
            (row) => LeaderboardSeason.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return seasons;
    } catch (error) {
      AppLogger.d('Failed to load active leaderboard seasons: $error');
      return _fallbackActiveSeasons();
    }
  }

  @override
  Future<List<SeasonLeaderboardEntry>> getSeasonRankings(
    String seasonId,
  ) async {
    final client = _connection.client;
    if (client == null) return _fallbackSeasonRankings(seasonId);

    try {
      final rows = await client
          .from('leaderboard_entries')
          .select()
          .eq('season_id', seasonId)
          .order('rank');
      final entries = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                SeasonLeaderboardEntry.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return entries;
    } catch (error) {
      AppLogger.d('Failed to load season rankings: $error');
      return _fallbackSeasonRankings(seasonId);
    }
  }

  @override
  Future<SeasonLeaderboardEntry?> getUserSeasonEntry(
    String seasonId,
    String userId,
  ) async {
    final entries = await getSeasonRankings(seasonId);
    for (final entry in entries) {
      if (entry.userId == userId) return entry;
    }
    return null;
  }

  @override
  Future<List<LeaderboardSeason>> getCompletedSeasons() async {
    final client = _connection.client;
    if (client == null) return _fallbackCompletedSeasons();

    try {
      final rows = await client
          .from('leaderboard_seasons')
          .select()
          .eq('status', 'completed')
          .order('ends_at', ascending: false);
      final seasons = (rows as List)
          .whereType<Map>()
          .map(
            (row) => LeaderboardSeason.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return seasons;
    } catch (error) {
      AppLogger.d('Failed to load completed leaderboard seasons: $error');
      return _fallbackCompletedSeasons();
    }
  }

  List<LeaderboardSeason> _fallbackActiveSeasons() {
    return allowEngagementSeedFallback
        ? fallbackActiveSeasons()
        : const <LeaderboardSeason>[];
  }

  List<SeasonLeaderboardEntry> _fallbackSeasonRankings(String seasonId) {
    return allowEngagementSeedFallback
        ? fallbackSeasonRankings(seasonId)
        : const <SeasonLeaderboardEntry>[];
  }

  List<LeaderboardSeason> _fallbackCompletedSeasons() {
    return allowEngagementSeedFallback
        ? fallbackCompletedSeasons()
        : const <LeaderboardSeason>[];
  }
}
