import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../core/utils/team_name_cleanup.dart';
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
      dynamic competitionRows;
      try {
        competitionRows = await client
            .from('app_competitions_ranked')
            .select(
              'id, name, short_name, country, catalog_rank, future_match_count',
            )
            .or(
              'name.ilike.$pattern,short_name.ilike.$pattern,country.ilike.$pattern',
            )
            .order('catalog_rank', ascending: true)
            .order('future_match_count', ascending: false)
            .order('name', ascending: true)
            .limit(12);
      } catch (error) {
        AppLogger.d('Failed to search ranked competitions view: $error');
        try {
          competitionRows = await client
              .from('app_competitions')
              .select('id, name, short_name, country, future_match_count')
              .or(
                'name.ilike.$pattern,short_name.ilike.$pattern,country.ilike.$pattern',
              )
              .order('future_match_count', ascending: false)
              .order('name', ascending: true)
              .limit(12);
        } catch (viewError) {
          AppLogger.d('Failed to search app competitions view: $viewError');
          competitionRows = await client
              .from('competitions')
              .select('id, name, short_name, country')
              .or(
                'name.ilike.$pattern,short_name.ilike.$pattern,country.ilike.$pattern',
              )
              .order('name', ascending: true)
              .limit(12);
        }
      }

      dynamic teamRows;
      try {
        teamRows = await client
            .from('team_catalog_entries')
            .select(
              'id, name, short_name, country, league_name, is_featured, fan_count',
            )
            .eq('is_active', true)
            .or(
              'name.ilike.$pattern,short_name.ilike.$pattern,country.ilike.$pattern,league_name.ilike.$pattern',
            )
            .order('is_featured', ascending: false)
            .order('fan_count', ascending: false)
            .order('name', ascending: true)
            .limit(12);
      } catch (error) {
        AppLogger.d('Failed to search team catalog view: $error');
        teamRows = await client
            .from('teams')
            .select('id, name, short_name, country, league_name, is_featured')
            .eq('is_active', true)
            .or(
              'name.ilike.$pattern,short_name.ilike.$pattern,country.ilike.$pattern,league_name.ilike.$pattern',
            )
            .order('is_featured', ascending: false)
            .order('name', ascending: true)
            .limit(24);
      }

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
          .where((row) => !isPlaceholderTeamName(row['name']?.toString()))
          .map(
            (row) => SearchResultModel(
              type: SearchResultType.team,
              id: row['id']?.toString() ?? '',
              title: (() {
                final name = normalizeTeamDisplayName(row['name']?.toString());
                return name.isNotEmpty ? name : 'Team';
              })(),
              subtitle:
                  row['league_name']?.toString() ??
                  row['country']?.toString() ??
                  'Club',
            ),
          )
          .where((result) => result.id.isNotEmpty)
          .take(12)
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
