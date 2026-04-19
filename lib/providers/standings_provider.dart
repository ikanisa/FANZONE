import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../features/home/data/home_dtos.dart' show CompetitionStandingsFilter;

import '../core/di/gateway_providers.dart';
import '../features/home/data/home_dtos.dart';
import '../models/standing_row_model.dart';

final competitionStandingsProvider = FutureProvider.family
    .autoDispose<List<StandingRowModel>, CompetitionStandingsFilter>((
      ref,
      filter,
    ) async {
      return ref.read(competitionCatalogGatewayProvider).getCompetitionStandings(filter);
    });
