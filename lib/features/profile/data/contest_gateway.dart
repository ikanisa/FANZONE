import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/community_contest_model.dart';
import 'engagement_gateway_shared.dart';

abstract interface class ContestGateway {
  Future<List<CommunityContest>> getOpenContests();

  Future<CommunityContest?> getContestForMatch(String matchId);

  Future<List<ContestEntry>> getContestEntries(String contestId);

  Future<ContestEntry?> getUserContestEntry(String contestId, String userId);

  Future<List<CommunityContest>> getSettledContests();
}

class SupabaseContestGateway implements ContestGateway {
  SupabaseContestGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<CommunityContest>> getOpenContests() async {
    final client = _connection.client;
    if (client == null) return _fallbackOpenContests();

    try {
      final rows = await client
          .from('community_contests')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false);
      final contests = (rows as List)
          .whereType<Map>()
          .map(
            (row) => CommunityContest.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return contests;
    } catch (error) {
      AppLogger.d('Failed to load open contests: $error');
      return _fallbackOpenContests();
    }
  }

  @override
  Future<CommunityContest?> getContestForMatch(String matchId) async {
    final contests = await getOpenContests();
    for (final contest in contests) {
      if (contest.matchId == matchId) return contest;
    }
    return fallbackContestForMatch(matchId);
  }

  @override
  Future<List<ContestEntry>> getContestEntries(String contestId) async {
    final client = _connection.client;
    if (client == null) return _fallbackContestEntries(contestId);

    try {
      final rows = await client
          .from('community_contest_entries')
          .select()
          .eq('contest_id', contestId)
          .order('created_at', ascending: false);
      final entries = (rows as List)
          .whereType<Map>()
          .map((row) => ContestEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return entries;
    } catch (error) {
      AppLogger.d('Failed to load contest entries: $error');
      return _fallbackContestEntries(contestId);
    }
  }

  @override
  Future<ContestEntry?> getUserContestEntry(
    String contestId,
    String userId,
  ) async {
    final entries = await getContestEntries(contestId);
    for (final entry in entries) {
      if (entry.userId == userId) return entry;
    }
    return null;
  }

  @override
  Future<List<CommunityContest>> getSettledContests() async {
    final client = _connection.client;
    if (client == null) return _fallbackSettledContests();

    try {
      final rows = await client
          .from('community_contests')
          .select()
          .eq('status', 'settled')
          .order('settled_at', ascending: false);
      final contests = (rows as List)
          .whereType<Map>()
          .map(
            (row) => CommunityContest.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return contests;
    } catch (error) {
      AppLogger.d('Failed to load settled contests: $error');
      return _fallbackSettledContests();
    }
  }

  List<CommunityContest> _fallbackOpenContests() {
    return allowEngagementSeedFallback
        ? fallbackOpenContests()
        : const <CommunityContest>[];
  }

  List<ContestEntry> _fallbackContestEntries(String contestId) {
    return allowEngagementSeedFallback
        ? fallbackContestEntries(contestId)
        : const <ContestEntry>[];
  }

  List<CommunityContest> _fallbackSettledContests() {
    return allowEngagementSeedFallback
        ? fallbackSettledContests()
        : const <CommunityContest>[];
  }
}
