import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/search_result_model.dart';
import 'home_dtos.dart';

abstract interface class SearchCatalogGateway {
  Future<SearchResults> search(SearchQueryDto query);
}

class SupabaseSearchCatalogGateway implements SearchCatalogGateway {
  SupabaseSearchCatalogGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<SearchResults> search(SearchQueryDto query) async {
    final normalized = query.value.trim().toLowerCase();
    if (normalized.isEmpty) return const SearchResults();
    final client = _connection.client;
    if (client == null) return const SearchResults();

    final pattern = '%$normalized%';

    try {
      final competitionRows = await client
          .from('competitions')
          .select('id, name, short_name, country')
          .or(
            'name.ilike.$pattern,short_name.ilike.$pattern,country.ilike.$pattern',
          )
          .order('name')
          .limit(12);
      final teamRows = await client
          .from('teams')
          .select('id, name, short_name, country, league_name')
          .or(
            'name.ilike.$pattern,short_name.ilike.$pattern,country.ilike.$pattern,league_name.ilike.$pattern',
          )
          .order('name')
          .limit(12);

      final competitionResults = (competitionRows as List)
          .whereType<Map>()
          .map(
            (row) => SearchResultModel(
              type: SearchResultType.competition,
              id: row['id']?.toString() ?? '',
              title: row['name']?.toString() ?? 'Competition',
              subtitle: row['country']?.toString() ?? '',
            ),
          )
          .where((result) => result.id.isNotEmpty)
          .toList(growable: false);

      final teamResults = (teamRows as List)
          .whereType<Map>()
          .map(
            (row) => SearchResultModel(
              type: SearchResultType.team,
              id: row['id']?.toString() ?? '',
              title: row['name']?.toString() ?? 'Team',
              subtitle:
                  row['league_name']?.toString() ??
                  row['country']?.toString() ??
                  'Club',
            ),
          )
          .where((result) => result.id.isNotEmpty)
          .toList(growable: false);

      return SearchResults(
        competitions: competitionResults,
        teams: teamResults,
      );
    } catch (error) {
      AppLogger.d('Failed to search competitions and teams: $error');
      return const SearchResults();
    }
  }
}
