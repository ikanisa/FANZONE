import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../data/team_search_database.dart';
import '../features/onboarding/data/onboarding_gateway.dart';
import 'auth_provider.dart';

final favoriteTeamRecordsProvider =
    FutureProvider.autoDispose<List<FavoriteTeamRecordDto>>((ref) async {
      ref.watch(authStateProvider);
      return getIt<OnboardingGateway>().getUserFavoriteTeams();
    });

final favoriteTeamIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final teams = ref.watch(favoriteTeamRecordsProvider).valueOrNull;
  if (teams == null) return const <String>{};
  return teams.map((team) => team.teamId).toSet();
});
