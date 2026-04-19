import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../models/team_model.dart';

final teamsProvider = FutureProvider.autoDispose<List<TeamModel>>((ref) async {
  ref.keepAlive();
  return ref.read(teamCatalogGatewayProvider).getTeams();
});

final teamsByCompetitionProvider = FutureProvider.family
    .autoDispose<List<TeamModel>, String>((ref, competitionId) async {
      return ref.read(teamCatalogGatewayProvider).getTeams(competitionId: competitionId);
    });

final teamProvider = FutureProvider.family.autoDispose<TeamModel?, String>((
  ref,
  teamId,
) async {
  return ref.read(teamCatalogGatewayProvider).getTeam(teamId);
});

final featuredTeamsProvider = FutureProvider.autoDispose<List<TeamModel>>((
  ref,
) async {
  ref.keepAlive();
  return ref.read(teamCatalogGatewayProvider).getTeams(featuredOnly: true);
});
