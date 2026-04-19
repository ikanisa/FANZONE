import '../../../config/app_config.dart';
import '../../../models/community_contest_model.dart';
import '../../../models/fan_identity_model.dart';
import '../../../models/leaderboard_season_model.dart';

bool get allowEngagementSeedFallback => AppConfig.isDevelopment;

List<CommunityContest> fallbackOpenContests() {
  if (!allowEngagementSeedFallback) return const <CommunityContest>[];
  return <CommunityContest>[_openContest];
}

CommunityContest? fallbackContestForMatch(String matchId) {
  for (final contest in fallbackOpenContests()) {
    if (contest.matchId == matchId) return contest;
  }
  return null;
}

List<ContestEntry> fallbackContestEntries(String contestId) {
  if (!allowEngagementSeedFallback || contestId != _openContest.id) {
    return const <ContestEntry>[];
  }
  return _contestEntries;
}

List<CommunityContest> fallbackSettledContests() {
  if (!allowEngagementSeedFallback) return const <CommunityContest>[];
  return <CommunityContest>[_settledContest];
}

List<LeaderboardSeason> fallbackActiveSeasons() {
  if (!allowEngagementSeedFallback) return const <LeaderboardSeason>[];
  return <LeaderboardSeason>[_activeSeason];
}

List<SeasonLeaderboardEntry> fallbackSeasonRankings(String seasonId) {
  if (!allowEngagementSeedFallback) {
    return const <SeasonLeaderboardEntry>[];
  }
  return seasonId == _activeSeason.id || seasonId == _completedSeason.id
      ? _seasonRankings
      : const <SeasonLeaderboardEntry>[];
}

List<LeaderboardSeason> fallbackCompletedSeasons() {
  if (!allowEngagementSeedFallback) return const <LeaderboardSeason>[];
  return <LeaderboardSeason>[_completedSeason];
}

List<FanLevel> fallbackFanLevels() {
  if (!allowEngagementSeedFallback) return const <FanLevel>[];
  return _fanLevels;
}

List<FanBadge> fallbackFanBadges() {
  if (!allowEngagementSeedFallback) return const <FanBadge>[];
  return _fanBadges;
}

FanProfile? fallbackFanProfileOrNull(String userId) {
  if (!allowEngagementSeedFallback) return null;
  return _seedFanProfile(userId);
}

List<EarnedBadge> fallbackEarnedBadges(String userId) {
  if (!allowEngagementSeedFallback) return const <EarnedBadge>[];
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

List<XpLogEntry> fallbackXpHistory(String userId) {
  if (!allowEngagementSeedFallback) return const <XpLogEntry>[];
  return _seedXpHistory(userId);
}

FanProfile _seedFanProfile(String userId) {
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

List<XpLogEntry> _seedXpHistory(String userId) {
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
