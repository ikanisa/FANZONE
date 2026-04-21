import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/league_constants.dart';
import '../core/di/gateway_providers.dart';
import '../models/competition_model.dart';

final competitionsProvider = FutureProvider.autoDispose<List<CompetitionModel>>(
  (ref) async {
    ref.keepAlive();
    return ref.read(competitionCatalogGatewayProvider).getCompetitions();
  },
);

final topCompetitionsProvider =
    FutureProvider.autoDispose<List<CompetitionModel>>((ref) async {
      ref.keepAlive();
      return ref
          .read(competitionCatalogGatewayProvider)
          .getCompetitions(tier: 1);
    });

final competitionProvider = FutureProvider.family
    .autoDispose<CompetitionModel?, String>((ref, competitionId) async {
      return ref
          .read(competitionCatalogGatewayProvider)
          .getCompetition(competitionId);
    });

final top5EuropeanLeaguesProvider =
    FutureProvider.autoDispose<List<CompetitionModel>>((ref) async {
      ref.keepAlive();
      final all = await ref.watch(competitionsProvider.future);
      final result = all
          .where(
            (competition) =>
                competitionCatalogRankByIdName(
                  competition.id,
                  competition.name,
                ) <
                kRestOfWorldCompetitionRank,
          )
          .toList(growable: false);
      return result;
    });

final otherLeaguesProvider = FutureProvider.autoDispose<List<CompetitionModel>>(
  (ref) async {
    ref.keepAlive();
    final all = await ref.watch(competitionsProvider.future);
    return all
        .where(
          (competition) =>
              competition.tier == 1 &&
              !isPriorityCompetitionByIdName(
                competition.id,
                competition.name,
              ) &&
              !isTop5Country(competition.country),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  },
);

final localLeaguesProvider = FutureProvider.family
    .autoDispose<List<CompetitionModel>, String>((ref, regionKey) async {
      final all = await ref.watch(competitionsProvider.future);
      // Use DB-driven bootstrap config for country-to-region mapping
      final bootstrapConfig = ref.read(bootstrapConfigProvider);
      final localCountryNames = bootstrapConfig.countryNamesForRegion(
        regionKey,
      );
      if (localCountryNames.isEmpty) return const [];

      return all
          .where(
            (c) =>
                c.tier == 1 &&
                !isTop5Country(c.country) &&
                localCountryNames.contains(c.country),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
