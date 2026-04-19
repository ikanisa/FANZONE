import 'package:injectable/injectable.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/community_contest_model.dart';
import '../../../models/fan_identity_model.dart';
import '../../../models/leaderboard_season_model.dart';

abstract interface class EngagementGateway {
  Future<List<CommunityContest>> getOpenContests();

  Future<CommunityContest?> getContestForMatch(String matchId);

  Future<List<ContestEntry>> getContestEntries(String contestId);

  Future<ContestEntry?> getUserContestEntry(String contestId, String userId);

  Future<List<CommunityContest>> getSettledContests();

  Future<List<LeaderboardSeason>> getActiveLeaderboardSeasons();

  Future<List<SeasonLeaderboardEntry>> getSeasonRankings(String seasonId);

  Future<SeasonLeaderboardEntry?> getUserSeasonEntry(
    String seasonId,
    String userId,
  );

  Future<List<LeaderboardSeason>> getCompletedSeasons();

  Future<List<FanLevel>> getFanLevels();

  Future<List<FanBadge>> getFanBadges();

  Future<FanProfile?> getFanProfile(String userId);

  Future<List<EarnedBadge>> getEarnedBadges(String userId);

  Future<List<XpLogEntry>> getXpHistory(String userId);
}

@LazySingleton(as: EngagementGateway)
class SupabaseEngagementGateway implements EngagementGateway {
  SupabaseEngagementGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<CommunityContest>> getOpenContests() async {
    final client = _connection.client;
    if (client == null) return [_openContest];

    try {
      final rows = await client
          .from('community_contests')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false);
      final contests = (rows as List)
          .whereType<Map>()
          .map((row) => CommunityContest.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return contests.isEmpty ? [_openContest] : contests;
    } catch (error) {
      AppLogger.d('Failed to load open contests: $error');
      return [_openContest];
    }
  }

  @override
  Future<CommunityContest?> getContestForMatch(String matchId) async {
    final contests = await getOpenContests();
    for (final contest in contests) {
      if (contest.matchId == matchId) return contest;
    }
    return null;
  }

  @override
  Future<List<ContestEntry>> getContestEntries(String contestId) async {
    final client = _connection.client;
    if (client == null) {
      return contestId == _openContest.id ? _contestEntries : const [];
    }

    try {
      final rows = await client
          .from('community_contest_entries')
          .select()
          .eq('contest_id', contestId)
          .order('created_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map((row) => ContestEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load contest entries: $error');
      return contestId == _openContest.id ? _contestEntries : const [];
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
    if (client == null) return [_settledContest];

    try {
      final rows = await client
          .from('community_contests')
          .select()
          .eq('status', 'settled')
          .order('settled_at', ascending: false);
      final contests = (rows as List)
          .whereType<Map>()
          .map((row) => CommunityContest.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return contests.isEmpty ? [_settledContest] : contests;
    } catch (error) {
      AppLogger.d('Failed to load settled contests: $error');
      return [_settledContest];
    }
  }

  @override
  Future<List<LeaderboardSeason>> getActiveLeaderboardSeasons() async {
    final client = _connection.client;
    if (client == null) return [_activeSeason];

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
      return seasons.isEmpty ? [_activeSeason] : seasons;
    } catch (error) {
      AppLogger.d('Failed to load active leaderboard seasons: $error');
      return [_activeSeason];
    }
  }

  @override
  Future<List<SeasonLeaderboardEntry>> getSeasonRankings(String seasonId) async {
    final client = _connection.client;
    if (client == null) {
      if (seasonId == _activeSeason.id || seasonId == _completedSeason.id) {
        return _seasonRankings;
      }
      return const [];
    }

    try {
      final rows = await client
          .from('leaderboard_entries')
          .select()
          .eq('season_id', seasonId)
          .order('rank');
      final entries = (rows as List)
          .whereType<Map>()
          .map(
            (row) => SeasonLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
      return entries.isEmpty ? _seasonRankings : entries;
    } catch (error) {
      AppLogger.d('Failed to load season rankings: $error');
      if (seasonId == _activeSeason.id || seasonId == _completedSeason.id) {
        return _seasonRankings;
      }
      return const [];
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
    if (client == null) return [_completedSeason];

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
      return seasons.isEmpty ? [_completedSeason] : seasons;
    } catch (error) {
      AppLogger.d('Failed to load completed leaderboard seasons: $error');
      return [_completedSeason];
    }
  }

  @override
  Future<List<FanLevel>> getFanLevels() async {
    final client = _connection.client;
    if (client == null) return _fanLevels;

    try {
      final rows = await client.from('fan_levels').select().order('level');
      final levels = (rows as List)
          .whereType<Map>()
          .map((row) => FanLevel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return levels.isEmpty ? _fanLevels : levels;
    } catch (error) {
      AppLogger.d('Failed to load fan levels: $error');
      return _fanLevels;
    }
  }

  @override
  Future<List<FanBadge>> getFanBadges() async {
    final client = _connection.client;
    if (client == null) return _fanBadges;

    try {
      final rows = await client.from('fan_badges').select().eq('is_active', true);
      final badges = (rows as List)
          .whereType<Map>()
          .map((row) => FanBadge.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return badges.isEmpty ? _fanBadges : badges;
    } catch (error) {
      AppLogger.d('Failed to load fan badges: $error');
      return _fanBadges;
    }
  }

  @override
  Future<FanProfile?> getFanProfile(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return _fallbackFanProfile(userId);
    }

    try {
      final row = await client
          .from('fan_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null
          ? _fallbackFanProfile(userId)
          : FanProfile.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load fan profile: $error');
      return _fallbackFanProfile(userId);
    }
  }

  @override
  Future<List<EarnedBadge>> getEarnedBadges(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return [
        EarnedBadge(
          id: 'earned_1',
          userId: userId,
          badgeId: _fanBadges.first.id,
          earnedAt: DateTime.now().subtract(const Duration(days: 4)),
          badge: _fanBadges.first,
        ),
      ];
    }

    try {
      final rows = await client
          .from('fan_earned_badges')
          .select('*, fan_badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map((row) => EarnedBadge.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load earned badges: $error');
      return [
        EarnedBadge(
          id: 'earned_1',
          userId: userId,
          badgeId: _fanBadges.first.id,
          earnedAt: DateTime.now().subtract(const Duration(days: 4)),
          badge: _fanBadges.first,
        ),
      ];
    }
  }

  @override
  Future<List<XpLogEntry>> getXpHistory(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return _fallbackXpHistory(userId);
    }

    try {
      final rows = await client
          .from('fan_xp_log')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final history = (rows as List)
          .whereType<Map>()
          .map((row) => XpLogEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return history.isEmpty ? _fallbackXpHistory(userId) : history;
    } catch (error) {
      AppLogger.d('Failed to load XP history: $error');
      return _fallbackXpHistory(userId);
    }
  }
}

FanProfile _fallbackFanProfile(String userId) {
  final preview = userId.length <= 4 ? userId : userId.substring(0, 4);
  return FanProfile(
    userId: userId,
    displayName: 'Fan #$preview',
    totalXp: 240,
    currentLevel: 2,
    reputationScore: 78,
    streakDays: 5,
    longestStreak: 12,
    lastActiveDate: DateTime.now().subtract(const Duration(hours: 3)),
  );
}

List<XpLogEntry> _fallbackXpHistory(String userId) {
  return [
    XpLogEntry(
      id: 'xp_1',
      userId: userId,
      action: 'prediction_correct',
      xpEarned: 30,
      referenceType: 'match',
      referenceId: 'match_live_1',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    XpLogEntry(
      id: 'xp_2',
      userId: userId,
      action: 'badge_earned',
      xpEarned: 50,
      referenceType: 'badge',
      referenceId: _fanBadges.first.id,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}

final CommunityContest _openContest = CommunityContest(
  id: 'contest_1',
  name: 'Liverpool vs Arsenal Fan Clash',
  matchId: 'match_live_1',
  homeTeamId: 'liverpool',
  awayTeamId: 'arsenal',
  homeFanCount: 241,
  awayFanCount: 198,
  homeAccuracyAvg: 0.61,
  awayAccuracyAvg: 0.57,
  createdAt: DateTime.now().subtract(const Duration(days: 1)),
);

final CommunityContest _settledContest = CommunityContest(
  id: 'contest_2',
  name: 'Barca vs Madrid Fan Clash',
  matchId: 'match_upcoming_1',
  homeTeamId: 'barcelona',
  awayTeamId: 'real-madrid',
  status: 'settled',
  homeFanCount: 180,
  awayFanCount: 176,
  homeAccuracyAvg: 0.73,
  awayAccuracyAvg: 0.69,
  winningFanClub: 'barcelona',
  createdAt: DateTime.now().subtract(const Duration(days: 10)),
  settledAt: DateTime.now().subtract(const Duration(days: 8)),
);

final List<ContestEntry> _contestEntries = <ContestEntry>[
  ContestEntry(
    id: 'entry_1',
    contestId: 'contest_1',
    userId: 'user_1',
    teamId: 'liverpool',
    predictedHomeScore: 2,
    predictedAwayScore: 1,
    accuracyScore: 0.8,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
];

final LeaderboardSeason _activeSeason = LeaderboardSeason(
  id: 'season_active_1',
  name: 'April Matchday Sprint',
  seasonType: 'monthly',
  startsAt: DateTime.now().subtract(const Duration(days: 10)),
  endsAt: DateTime.now().add(const Duration(days: 20)),
  status: 'active',
  prizePoolFet: 5000,
);

final LeaderboardSeason _completedSeason = LeaderboardSeason(
  id: 'season_completed_1',
  name: 'March Matchday Sprint',
  seasonType: 'monthly',
  startsAt: DateTime.now().subtract(const Duration(days: 40)),
  endsAt: DateTime.now().subtract(const Duration(days: 10)),
  status: 'completed',
  prizePoolFet: 4500,
);

final List<SeasonLeaderboardEntry> _seasonRankings = <SeasonLeaderboardEntry>[
  const SeasonLeaderboardEntry(
    id: 'season_entry_1',
    seasonId: 'season_active_1',
    userId: 'user_1',
    points: 240,
    correctPredictions: 18,
    totalPredictions: 24,
    exactScores: 6,
    rank: 1,
    prizeFet: 1200,
    displayName: 'FAN Malta',
    currentLevel: 2,
  ),
  const SeasonLeaderboardEntry(
    id: 'season_entry_2',
    seasonId: 'season_active_1',
    userId: 'user_2',
    points: 220,
    correctPredictions: 17,
    totalPredictions: 24,
    exactScores: 5,
    rank: 2,
    prizeFet: 900,
    displayName: 'FAN Kigali',
    currentLevel: 2,
  ),
];

const List<FanLevel> _fanLevels = <FanLevel>[
  FanLevel(
    level: 1,
    name: 'Starter',
    title: 'First Whistle',
    minXp: 0,
    iconName: 'sparkles',
    colorHex: '#22D3EE',
  ),
  FanLevel(
    level: 2,
    name: 'Supporter',
    title: 'Matchday Regular',
    minXp: 200,
    iconName: 'shield',
    colorHex: '#2563EB',
  ),
  FanLevel(
    level: 3,
    name: 'Legend',
    title: 'Ultra Leader',
    minXp: 500,
    iconName: 'trophy',
    colorHex: '#F59E0B',
  ),
];

const List<FanBadge> _fanBadges = <FanBadge>[
  FanBadge(
    id: 'badge_1',
    name: 'Streak Starter',
    description: 'Predicted correctly on three straight matchdays.',
    category: 'milestone',
    iconName: 'flame',
    rarity: 'rare',
    xpReward: 50,
  ),
];
