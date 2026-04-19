import 'package:injectable/injectable.dart';

import '../../../models/search_result_model.dart';
import 'competition_catalog_gateway.dart';
import 'home_dtos.dart';
import 'team_catalog_gateway.dart';

abstract interface class SearchCatalogGateway {
  Future<SearchResults> search(SearchQueryDto query);
}

@LazySingleton(as: SearchCatalogGateway)
class SupabaseSearchCatalogGateway implements SearchCatalogGateway {
  SupabaseSearchCatalogGateway(this._competitions, this._teams);

  final CompetitionCatalogGateway _competitions;
  final TeamCatalogGateway _teams;

  @override
  Future<SearchResults> search(SearchQueryDto query) async {
    final normalized = query.value.trim().toLowerCase();
    if (normalized.isEmpty) return const SearchResults();

    final competitions = await _competitions.getCompetitions();
    final teams = await _teams.getTeams();

    final competitionResults = competitions
        .where((competition) {
          final haystack =
              '${competition.name} ${competition.shortName} ${competition.country}'
                  .toLowerCase();
          return haystack.contains(normalized);
        })
        .map(
          (competition) => SearchResultModel(
            type: SearchResultType.competition,
            id: competition.id,
            title: competition.name,
            subtitle: competition.country,
          ),
        )
        .toList(growable: false);

    final teamResults = teams
        .where((team) {
          final haystack =
              '${team.name} ${team.shortName ?? ''} ${team.country ?? ''} ${team.leagueName ?? ''} ${team.aliases.join(' ')}'
                  .toLowerCase();
          return haystack.contains(normalized);
        })
        .map(
          (team) => SearchResultModel(
            type: SearchResultType.team,
            id: team.id,
            title: team.name,
            subtitle: team.leagueName ?? team.country ?? 'Club',
          ),
        )
        .toList(growable: false);

    return SearchResults(competitions: competitionResults, teams: teamResults);
  }
}
