import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/competition_model.dart';
import '../../../models/standing_row_model.dart';
import 'home_dtos.dart';

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

  @override
  Future<List<CompetitionModel>> getCompetitions({
    int? tier,
    bool featuredOnly = false,
  }) async {
    final client = _connection.client;
    if (client == null) return const <CompetitionModel>[];

    try {
      final rows = await client.from('competitions').select();
      final competitions = (rows as List)
          .whereType<Map>()
          .map(
            (row) => CompetitionModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);

      Iterable<CompetitionModel> result = competitions;
      if (tier != null) {
        result = result.where((c) => c.tier == tier);
      }
      if (featuredOnly) {
        result = result.where((c) => c.isFeatured);
      }
      return result.toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load competitions: $error');
      return const <CompetitionModel>[];
    }
  }

  @override
  Future<CompetitionModel?> getCompetition(String competitionId) async {
    final competitions = await getCompetitions();
    for (final competition in competitions) {
      if (competition.id == competitionId) return competition;
    }
    return null;
  }

  @override
  Future<List<StandingRowModel>> getCompetitionStandings(
    CompetitionStandingsFilter filter,
  ) async {
    final client = _connection.client;
    if (client == null) return const <StandingRowModel>[];

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
      return const <StandingRowModel>[];
    }
  }
}
