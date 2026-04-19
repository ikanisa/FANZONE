import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../features/home/data/home_dtos.dart' show CompetitionStandingsFilter;

import '../core/di/injection.dart';
import '../features/home/data/competition_catalog_gateway.dart';
import '../features/home/data/home_dtos.dart';
import '../models/standing_row_model.dart';

final competitionStandingsProvider = FutureProvider.family
    .autoDispose<List<StandingRowModel>, CompetitionStandingsFilter>((
      ref,
      filter,
    ) async {
      return getIt<CompetitionCatalogGateway>().getCompetitionStandings(filter);
    });
