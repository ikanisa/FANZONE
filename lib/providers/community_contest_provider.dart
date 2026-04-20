import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../models/community_contest_model.dart';
import 'auth_provider.dart';

final openContestsProvider = FutureProvider.autoDispose<List<CommunityContest>>(
  (ref) async {
    return ref.read(contestGatewayProvider).getOpenContests();
  },
);

final contestForMatchProvider = FutureProvider.family
    .autoDispose<CommunityContest?, String>((ref, matchId) async {
      return ref.read(contestGatewayProvider).getContestForMatch(matchId);
    });

final contestEntriesProvider = FutureProvider.family
    .autoDispose<List<ContestEntry>, String>((ref, contestId) async {
      return ref.read(contestGatewayProvider).getContestEntries(contestId);
    });

final userContestEntryProvider = FutureProvider.family
    .autoDispose<ContestEntry?, String>((ref, contestId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      return ref
          .read(contestGatewayProvider)
          .getUserContestEntry(contestId, user.id);
    });

final settledContestsProvider =
    FutureProvider.autoDispose<List<CommunityContest>>((ref) async {
      return ref.read(contestGatewayProvider).getSettledContests();
    });
