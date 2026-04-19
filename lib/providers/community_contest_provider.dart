import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../features/profile/data/engagement_gateway.dart';
import '../models/community_contest_model.dart';
import 'auth_provider.dart';

final openContestsProvider =
    FutureProvider.autoDispose<List<CommunityContest>>((ref) async {
      return getIt<EngagementGateway>().getOpenContests();
    });

final contestForMatchProvider = FutureProvider.family
    .autoDispose<CommunityContest?, String>((ref, matchId) async {
      return getIt<EngagementGateway>().getContestForMatch(matchId);
    });

final contestEntriesProvider = FutureProvider.family
    .autoDispose<List<ContestEntry>, String>((ref, contestId) async {
      return getIt<EngagementGateway>().getContestEntries(contestId);
    });

final userContestEntryProvider = FutureProvider.family
    .autoDispose<ContestEntry?, String>((ref, contestId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      return getIt<EngagementGateway>().getUserContestEntry(contestId, user.id);
    });

final settledContestsProvider =
    FutureProvider.autoDispose<List<CommunityContest>>((ref) async {
      return getIt<EngagementGateway>().getSettledContests();
    });
