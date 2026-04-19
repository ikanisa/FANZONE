import 'package:injectable/injectable.dart';

import '../../../models/community_contest_model.dart';
import '../../../models/fan_identity_model.dart';
import '../../../models/leaderboard_season_model.dart';
import 'contest_gateway.dart';
import 'fan_profile_gateway.dart';
import 'season_leaderboard_gateway.dart';

abstract interface class EngagementGateway
    implements ContestGateway, SeasonLeaderboardGateway, FanProfileGateway {}

@LazySingleton(as: EngagementGateway)
class SupabaseEngagementGateway implements EngagementGateway {
  SupabaseEngagementGateway(
    this._contests,
    this._leaderboards,
    this._fanProfiles,
  );

  final ContestGateway _contests;
  final SeasonLeaderboardGateway _leaderboards;
  final FanProfileGateway _fanProfiles;

  @override
  Future<List<CommunityContest>> getOpenContests() =>
      _contests.getOpenContests();

  @override
  Future<CommunityContest?> getContestForMatch(String matchId) =>
      _contests.getContestForMatch(matchId);

  @override
  Future<List<ContestEntry>> getContestEntries(String contestId) =>
      _contests.getContestEntries(contestId);

  @override
  Future<ContestEntry?> getUserContestEntry(String contestId, String userId) =>
      _contests.getUserContestEntry(contestId, userId);

  @override
  Future<List<CommunityContest>> getSettledContests() =>
      _contests.getSettledContests();

  @override
  Future<List<LeaderboardSeason>> getActiveLeaderboardSeasons() =>
      _leaderboards.getActiveLeaderboardSeasons();

  @override
  Future<List<SeasonLeaderboardEntry>> getSeasonRankings(String seasonId) =>
      _leaderboards.getSeasonRankings(seasonId);

  @override
  Future<SeasonLeaderboardEntry?> getUserSeasonEntry(
    String seasonId,
    String userId,
  ) => _leaderboards.getUserSeasonEntry(seasonId, userId);

  @override
  Future<List<LeaderboardSeason>> getCompletedSeasons() =>
      _leaderboards.getCompletedSeasons();

  @override
  Future<List<FanLevel>> getFanLevels() => _fanProfiles.getFanLevels();

  @override
  Future<List<FanBadge>> getFanBadges() => _fanProfiles.getFanBadges();

  @override
  Future<FanProfile?> getFanProfile(String userId) =>
      _fanProfiles.getFanProfile(userId);

  @override
  Future<List<EarnedBadge>> getEarnedBadges(String userId) =>
      _fanProfiles.getEarnedBadges(userId);

  @override
  Future<List<XpLogEntry>> getXpHistory(String userId) =>
      _fanProfiles.getXpHistory(userId);
}
