import '../../../core/constants/league_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/competition_model.dart';
import '../../../models/standing_row_model.dart';
import 'home_dtos.dart';
import 'sports_data_exception.dart';

abstract interface class CompetitionCatalogGateway {
  Future<List<CompetitionModel>> getCompetitions({
    int? tier,
    bool featuredOnly,
  });

  Future<CompetitionModel?> getCompetition(String competitionId);

  Future<List<StandingRowModel>> getCompetitionStandings(
    CompetitionStandingsFilter filter,
  );
}

class SupabaseCompetitionCatalogGateway implements CompetitionCatalogGateway {
  SupabaseCompetitionCatalogGateway(this._connection);

  final SupabaseConnection _connection;

  Never _throwUnavailable(String operation) {
    throw SportsDataUnavailableException(
      'Sports data is unavailable for $operation.',
    );
  }

  List<CompetitionModel> _sortCompetitions(
    List<CompetitionModel> competitions,
  ) {
    final sorted = [...competitions];
    sorted.sort((left, right) {
      final leftRank = competitionCatalogRank(
        id: left.id,
        name: left.name,
        catalogRank: left.catalogRank,
      );
      final rightRank = competitionCatalogRank(
        id: right.id,
        name: right.name,
        catalogRank: right.catalogRank,
      );
      if (leftRank != rightRank) {
        return leftRank.compareTo(rightRank);
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return sorted;
  }

  CompetitionModel _mapCompetitionRow(Map<String, dynamic> row) {
    final normalized = <String, dynamic>{
      'id': row['id'],
      'name': row['name'],
      'short_name': row['short_name'] ?? row['name'],
      'country': row['country'] ?? row['country_or_region'] ?? '',
      'tier': row['tier'] ?? 1,
      'competition_type': row['competition_type'],
      'is_featured': row['is_featured'] == true,
      'is_international': row['is_international'] == true,
      'is_active': row['is_active'] != false,
      'current_season_id': row['current_season_id'],
      'current_season_label': row['current_season_label'] ?? row['season'],
      'future_match_count': (row['future_match_count'] as num?)?.toInt() ?? 0,
      'catalog_rank': (row['catalog_rank'] as num?)?.toInt(),
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    };
    return CompetitionModel.fromJson(normalized);
  }

  @override
  Future<List<CompetitionModel>> getCompetitions({
    int? tier,
    bool featuredOnly = false,
  }) async {
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('competition loading');
    }

    try {
      dynamic rows;
      if (featuredOnly) {
        var query = client.from('competitions').select();
        if (tier != null) {
          query = query.eq('tier', tier);
        }
        rows = await query
            .eq('is_featured', true)
            .eq('is_active', true)
            .order('name', ascending: true);
      } else {
        var query = client.from('app_competitions_ranked').select();
        if (tier != null) {
          query = query.eq('tier', tier);
        }
        rows = await query
            .eq('is_active', true)
            .order('catalog_rank', ascending: true)
            .order('future_match_count', ascending: false)
            .order('name', ascending: true);
      }
      final competitions = (rows as List)
          .whereType<Map>()
          .map((row) => _mapCompetitionRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return featuredOnly ? _sortCompetitions(competitions) : competitions;
    } catch (error) {
      AppLogger.d('Failed to load competitions: $error');
      if (error is SportsDataException) rethrow;
      throw SportsDataQueryException(
        'Failed to load competitions.',
        cause: error,
      );
    }
  }

  @override
  Future<CompetitionModel?> getCompetition(String competitionId) async {
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('competition details');
    }

    try {
      dynamic row = await client
          .from('app_competitions_ranked')
          .select()
          .eq('id', competitionId)
          .maybeSingle();
      row ??= await client
          .from('competitions')
          .select()
          .eq('id', competitionId)
          .maybeSingle();
      if (row == null) return null;
      return _mapCompetitionRow(
        Map<String, dynamic>.from(row as Map<dynamic, dynamic>),
      );
    } catch (error) {
      AppLogger.d('Failed to load competition $competitionId: $error');
      throw SportsDataQueryException(
        'Failed to load competition details for $competitionId.',
        cause: error,
      );
    }
  }

  @override
  Future<List<StandingRowModel>> getCompetitionStandings(
    CompetitionStandingsFilter filter,
  ) async {
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('standings');
    }

    try {
      var query = client
          .from('competition_standings')
          .select()
          .eq('competition_id', filter.competitionId);
      if (filter.season != null && filter.season!.trim().isNotEmpty) {
        query = query.eq('season', filter.season!.trim());
      }
      final rows = await query.order('position');
      final standings = (rows as List)
          .whereType<Map>()
          .map(
            (row) => StandingRowModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return standings;
    } catch (error) {
      AppLogger.d('Failed to load standings: $error');
      if (error is SportsDataException) rethrow;
      throw SportsDataQueryException(
        'Failed to load standings for ${filter.competitionId}.',
        cause: error,
      );
    }
  }
}
