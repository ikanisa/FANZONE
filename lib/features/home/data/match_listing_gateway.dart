
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/match_model.dart';
import 'home_dtos.dart';
import 'matches_gateway_shared.dart';

abstract interface class MatchListingGateway {
  Future<List<MatchModel>> getMatches(MatchesFilter filter);

  Stream<MatchModel?> watchMatch(String matchId);

  Stream<List<MatchModel>> watchMatchesByDate(DateTime date);

  Stream<List<MatchModel>> watchCompetitionMatches(String competitionId);

  Stream<List<MatchModel>> watchTeamMatches(String teamId);

  Stream<List<MatchModel>> watchUpcomingMatches();
}

class SupabaseMatchListingGateway implements MatchListingGateway {
  SupabaseMatchListingGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<MatchModel>> getMatches(MatchesFilter filter) async {
    final client = _connection.client;
    if (client == null) return fallbackMatchesForFilter(filter);

    try {
      var query = client.from('matches').select();
      if (filter.competitionId != null && filter.competitionId!.isNotEmpty) {
        query = query.eq('competition_id', filter.competitionId!);
      }
      if (filter.teamId != null && filter.teamId!.isNotEmpty) {
        query = query.or(
          'home_team_id.eq.${filter.teamId},away_team_id.eq.${filter.teamId}',
        );
      }
      if (filter.status != null && filter.status!.isNotEmpty) {
        query = query.eq('status', filter.status!);
      }
      if (filter.dateFrom != null && filter.dateFrom!.isNotEmpty) {
        query = query.gte('date', filter.dateFrom!);
      }
      if (filter.dateTo != null && filter.dateTo!.isNotEmpty) {
        query = query.lte('date', filter.dateTo!);
      }

      final rows = await query
          .order('date', ascending: filter.ascending)
          .limit(filter.limit);

      final matches = (rows as List)
          .whereType<Map>()
          .map((row) => MatchModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      return matches;
    } catch (error) {
      AppLogger.d('Failed to load matches: $error');
      return fallbackMatchesForFilter(filter);
    }
  }

  @override
  Stream<MatchModel?> watchMatch(String matchId) {
    return pollMatchStream<MatchModel?>(() async {
      final matches = await getMatches(const MatchesFilter(limit: 200));
      for (final match in matches) {
        if (match.id == matchId) return match;
      }
      return null;
    });
  }

  @override
  Stream<List<MatchModel>> watchMatchesByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();
    return pollMatchStream<List<MatchModel>>(
      () => getMatches(
        MatchesFilter(
          dateFrom: start,
          dateTo: end,
          limit: 200,
          ascending: true,
        ),
      ),
    );
  }

  @override
  Stream<List<MatchModel>> watchCompetitionMatches(String competitionId) {
    return pollMatchStream<List<MatchModel>>(
      () => getMatches(
        MatchesFilter(
          competitionId: competitionId,
          limit: 200,
          ascending: true,
        ),
      ),
    );
  }

  @override
  Stream<List<MatchModel>> watchTeamMatches(String teamId) {
    return pollMatchStream<List<MatchModel>>(
      () => getMatches(
        MatchesFilter(teamId: teamId, limit: 200, ascending: true),
      ),
    );
  }

  @override
  Stream<List<MatchModel>> watchUpcomingMatches() {
    return pollMatchStream<List<MatchModel>>(
      () => getMatches(
        MatchesFilter(
          status: 'upcoming',
          dateFrom: DateTime.now().toIso8601String(),
          limit: 200,
          ascending: true,
        ),
      ),
    );
  }
}
