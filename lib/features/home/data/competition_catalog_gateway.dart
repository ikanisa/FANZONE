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
      final leftRank = competitionCatalogRankByIdName(left.id, left.name);
      final rightRank = competitionCatalogRankByIdName(right.id, right.name);
      if (leftRank != rightRank) {
        return leftRank.compareTo(rightRank);
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return sorted;
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
      var usedRankedView = false;
      try {
        var query = client.from('app_competitions_ranked').select();
        if (tier != null) {
          query = query.eq('tier', tier);
        }
        if (featuredOnly) {
          query = query.eq('is_featured', true);
        }
        rows = await query
            .order('catalog_rank', ascending: true)
            .order('future_match_count', ascending: false)
            .order('name', ascending: true);
        usedRankedView = true;
      } catch (error) {
        AppLogger.d('Failed to load ranked app competitions view: $error');
        try {
          var fallbackViewQuery = client.from('app_competitions').select();
          if (tier != null) {
            fallbackViewQuery = fallbackViewQuery.eq('tier', tier);
          }
          if (featuredOnly) {
            fallbackViewQuery = fallbackViewQuery.eq('is_featured', true);
          }
          rows = await fallbackViewQuery
              .order('future_match_count', ascending: false)
              .order('name', ascending: true);
        } catch (viewError) {
          AppLogger.d('Failed to load app competitions view: $viewError');
          var fallbackQuery = client.from('competitions').select();
          if (tier != null) {
            fallbackQuery = fallbackQuery.eq('tier', tier);
          }
          if (featuredOnly) {
            fallbackQuery = fallbackQuery.eq('is_featured', true);
          }
          rows = await fallbackQuery.order('name', ascending: true);
        }
      }
      final competitions = (rows as List)
          .whereType<Map>()
          .map(
            (row) => CompetitionModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return usedRankedView ? competitions : _sortCompetitions(competitions);
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
      dynamic row;
      try {
        row = await client
            .from('app_competitions_ranked')
            .select()
            .eq('id', competitionId)
            .maybeSingle();
      } catch (error) {
        AppLogger.d(
          'Failed to load ranked app competition $competitionId: $error',
        );
        try {
          row = await client
              .from('app_competitions')
              .select()
              .eq('id', competitionId)
              .maybeSingle();
        } catch (viewError) {
          AppLogger.d(
            'Failed to load app competition $competitionId: $viewError',
          );
          row = await client
              .from('competitions')
              .select()
              .eq('id', competitionId)
              .maybeSingle();
        }
      }
      if (row == null) return null;
      return CompetitionModel.fromJson(
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
      dynamic rows;
      try {
        rows = await client.rpc(
          'app_competition_standings',
          params: {
            'p_competition_id': filter.competitionId,
            'p_season': filter.season?.trim(),
          },
        );
      } catch (error) {
        AppLogger.d('Failed to load standings via RPC: $error');
        var query = client
            .from('competition_standings')
            .select()
            .eq('competition_id', filter.competitionId);
        if (filter.season != null && filter.season!.trim().isNotEmpty) {
          query = query.eq('season', filter.season!.trim());
        }
        rows = await query.order('position');
      }
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
