import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/league_constants.dart';
import '../core/di/injection.dart';
import '../features/home/data/competition_catalog_gateway.dart';
import '../models/competition_model.dart';

final competitionsProvider = FutureProvider.autoDispose<List<CompetitionModel>>(
  (ref) async {
    ref.keepAlive();
    return getIt<CompetitionCatalogGateway>().getCompetitions();
  },
);

final topCompetitionsProvider =
    FutureProvider.autoDispose<List<CompetitionModel>>((ref) async {
      ref.keepAlive();
      return getIt<CompetitionCatalogGateway>().getCompetitions(tier: 1);
    });

final competitionProvider = FutureProvider.family
    .autoDispose<CompetitionModel?, String>((ref, competitionId) async {
      return getIt<CompetitionCatalogGateway>().getCompetition(competitionId);
    });

final top5EuropeanLeaguesProvider =
    FutureProvider.autoDispose<List<CompetitionModel>>((ref) async {
      ref.keepAlive();
      final all = await ref.watch(competitionsProvider.future);
      final result = <CompetitionModel>[];
      for (final country in kTop5EuropeanCountries) {
        final match = all
            .where((c) => c.country == country && c.tier == 1)
            .firstOrNull;
        if (match != null) result.add(match);
      }
      return result;
    });

final otherLeaguesProvider = FutureProvider.autoDispose<List<CompetitionModel>>(
  (ref) async {
    ref.keepAlive();
    final all = await ref.watch(competitionsProvider.future);
    return all.where((c) => c.tier == 1 && !isTop5Country(c.country)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  },
);

final localLeaguesProvider = FutureProvider.family
    .autoDispose<List<CompetitionModel>, String>((ref, regionKey) async {
      final all = await ref.watch(competitionsProvider.future);
      final localCountries = _countriesForRegion(regionKey);
      if (localCountries.isEmpty) return const [];

      return all
          .where(
            (c) =>
                c.tier == 1 &&
                !isTop5Country(c.country) &&
                localCountries.contains(c.country),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });

List<String> _countriesForRegion(String regionKey) {
  switch (regionKey) {
    case 'africa':
      return const [
        'Rwanda',
        'Nigeria',
        'Egypt',
        'South Africa',
        'Tanzania',
        'Kenya',
        'Uganda',
        'Ghana',
        'Tunisia',
        'Morocco',
        'DR Congo',
        'Senegal',
        'Cameroon',
        'Algeria',
        'Ethiopia',
      ];
    case 'europe':
      return const [
        'Malta',
        'Netherlands',
        'Portugal',
        'Belgium',
        'Turkey',
        'Scotland',
        'Switzerland',
        'Sweden',
        'Norway',
        'Denmark',
        'Poland',
        'Austria',
        'Greece',
        'Czech Republic',
        'Romania',
      ];
    case 'north_america':
    case 'americas':
      return const [
        'United States',
        'Canada',
        'Mexico',
        'Brazil',
        'Argentina',
        'Colombia',
        'Chile',
        'Peru',
      ];
    default:
      return const [];
  }
}
