import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../features/profile/data/engagement_gateway.dart';
import '../models/leaderboard_season_model.dart';
import 'auth_provider.dart';

final activeLeaderboardSeasonsProvider =
    FutureProvider.autoDispose<List<LeaderboardSeason>>((ref) async {
      return getIt<EngagementGateway>().getActiveLeaderboardSeasons();
    });

final seasonRankingsProvider = FutureProvider.family
    .autoDispose<List<SeasonLeaderboardEntry>, String>((ref, seasonId) async {
      return getIt<EngagementGateway>().getSeasonRankings(seasonId);
    });

final userSeasonEntryProvider = FutureProvider.family
    .autoDispose<SeasonLeaderboardEntry?, String>((ref, seasonId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      return getIt<EngagementGateway>().getUserSeasonEntry(seasonId, user.id);
    });

final completedSeasonsProvider =
    FutureProvider.autoDispose<List<LeaderboardSeason>>((ref) async {
      return getIt<EngagementGateway>().getCompletedSeasons();
    });
