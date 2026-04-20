import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../models/leaderboard_season_model.dart';
import 'auth_provider.dart';

final activeLeaderboardSeasonsProvider =
    FutureProvider.autoDispose<List<LeaderboardSeason>>((ref) async {
      return ref
          .read(seasonLeaderboardGatewayProvider)
          .getActiveLeaderboardSeasons();
    });

final seasonRankingsProvider = FutureProvider.family
    .autoDispose<List<SeasonLeaderboardEntry>, String>((ref, seasonId) async {
      return ref
          .read(seasonLeaderboardGatewayProvider)
          .getSeasonRankings(seasonId);
    });

final userSeasonEntryProvider = FutureProvider.family
    .autoDispose<SeasonLeaderboardEntry?, String>((ref, seasonId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      return ref
          .read(seasonLeaderboardGatewayProvider)
          .getUserSeasonEntry(seasonId, user.id);
    });

final completedSeasonsProvider =
    FutureProvider.autoDispose<List<LeaderboardSeason>>((ref) async {
      return ref.read(seasonLeaderboardGatewayProvider).getCompletedSeasons();
    });
