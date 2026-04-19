import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../features/home/data/catalog_gateway.dart';
import '../models/team_model.dart';

final teamsProvider = FutureProvider.autoDispose<List<TeamModel>>((ref) async {
  ref.keepAlive();
  return getIt<CatalogGateway>().getTeams();
});

final teamsByCompetitionProvider = FutureProvider.family
    .autoDispose<List<TeamModel>, String>((ref, competitionId) async {
      return getIt<CatalogGateway>().getTeams(competitionId: competitionId);
    });

final teamProvider = FutureProvider.family.autoDispose<TeamModel?, String>((
  ref,
  teamId,
) async {
  return getIt<CatalogGateway>().getTeam(teamId);
});

final featuredTeamsProvider = FutureProvider.autoDispose<List<TeamModel>>((
  ref,
) async {
  ref.keepAlive();
  return getIt<CatalogGateway>().getTeams(featuredOnly: true);
});
