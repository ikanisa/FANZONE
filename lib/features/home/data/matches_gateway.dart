import 'package:injectable/injectable.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/live_match_event.dart';
import '../../../models/match_advanced_stats_model.dart';
import '../../../models/match_ai_analysis_model.dart';
import '../../../models/match_event_model.dart';
import '../../../models/match_model.dart';
import '../../../models/match_odds_model.dart';
import '../../../models/match_player_stats_model.dart';
import 'home_dtos.dart';

abstract interface class MatchesGateway {
  Future<List<MatchModel>> getMatches(MatchesFilter filter);

  Stream<MatchModel?> watchMatch(String matchId);

  Stream<List<MatchModel>> watchMatchesByDate(DateTime date);

  Stream<List<MatchModel>> watchCompetitionMatches(String competitionId);

  Stream<List<MatchModel>> watchTeamMatches(String teamId);

  Stream<List<MatchModel>> watchUpcomingMatches();

  Stream<List<LiveMatchEvent>> watchLiveMatchEvents(String matchId);

  Stream<MatchOddsModel?> watchMatchOdds(String matchId);

  Stream<MatchAdvancedStats?> watchAdvancedStats(String matchId);

  Stream<List<MatchPlayerStats>> watchPlayerStats(String matchId);

  Stream<List<MatchEventModel>> watchMatchEvents(String matchId);

  Future<MatchAiAnalysis?> getMatchAiAnalysis(String matchId);
}

@LazySingleton(as: MatchesGateway)
class SupabaseMatchesGateway implements MatchesGateway {
  SupabaseMatchesGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<MatchModel>> getMatches(MatchesFilter filter) async {
    final fallback = _applyFilter(_fallbackMatches(), filter);
    final client = _connection.client;
    if (client == null) return fallback;

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

      final rows = await query.order(
        'date',
        ascending: filter.ascending,
      ).limit(filter.limit);

      final matches = (rows as List)
          .whereType<Map>()
          .map((row) => MatchModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      return matches.isEmpty ? fallback : matches;
    } catch (error) {
      AppLogger.d('Failed to load matches: $error');
      return fallback;
    }
  }

  @override
  Stream<MatchModel?> watchMatch(String matchId) async* {
    final matches = await getMatches(const MatchesFilter(limit: 200));
    for (final match in matches) {
      if (match.id == matchId) {
        yield match;
        return;
      }
    }
    yield null;
  }

  @override
  Stream<List<MatchModel>> watchMatchesByDate(DateTime date) async* {
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();
    yield await getMatches(
      MatchesFilter(dateFrom: start, dateTo: end, limit: 200, ascending: true),
    );
  }

  @override
  Stream<List<MatchModel>> watchCompetitionMatches(
    String competitionId,
  ) async* {
    yield await getMatches(
      MatchesFilter(competitionId: competitionId, limit: 200, ascending: true),
    );
  }

  @override
  Stream<List<MatchModel>> watchTeamMatches(String teamId) async* {
    yield await getMatches(
      MatchesFilter(teamId: teamId, limit: 200, ascending: true),
    );
  }

  @override
  Stream<List<MatchModel>> watchUpcomingMatches() async* {
    yield await getMatches(
      MatchesFilter(
        status: 'upcoming',
        dateFrom: DateTime.now().toIso8601String(),
        limit: 200,
        ascending: true,
      ),
    );
  }

  @override
  Stream<List<LiveMatchEvent>> watchLiveMatchEvents(String matchId) async* {
    final client = _connection.client;
    if (client == null) {
      yield const [];
      return;
    }

    try {
      final rows = await client
          .from('live_match_events')
          .select()
          .eq('match_id', matchId)
          .order('created_at');
      yield (rows as List)
          .whereType<Map>()
          .map((row) => LiveMatchEvent.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load live match events: $error');
      yield const [];
    }
  }

  @override
  Stream<MatchOddsModel?> watchMatchOdds(String matchId) async* {
    final client = _connection.client;
    if (client == null) {
      yield _fallbackOdds(matchId);
      return;
    }

    try {
      final row = await client
          .from('match_odds_cache')
          .select()
          .eq('match_id', matchId)
          .maybeSingle();
      if (row == null) {
        yield _fallbackOdds(matchId);
        return;
      }
      yield MatchOddsModel.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load match odds: $error');
      yield _fallbackOdds(matchId);
    }
  }

  @override
  Stream<MatchAdvancedStats?> watchAdvancedStats(String matchId) async* {
    final client = _connection.client;
    if (client == null) {
      yield null;
      return;
    }

    try {
      final row = await client
          .from('match_advanced_stats')
          .select()
          .eq('match_id', matchId)
          .maybeSingle();
      yield row == null
          ? null
          : MatchAdvancedStats.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load advanced stats: $error');
      yield null;
    }
  }

  @override
  Stream<List<MatchPlayerStats>> watchPlayerStats(String matchId) async* {
    final client = _connection.client;
    if (client == null) {
      yield const [];
      return;
    }

    try {
      final rows = await client
          .from('match_player_stats')
          .select()
          .eq('match_id', matchId)
          .order('rating', ascending: false);
      yield (rows as List)
          .whereType<Map>()
          .map(
            (row) => MatchPlayerStats.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load player stats: $error');
      yield const [];
    }
  }

  @override
  Stream<List<MatchEventModel>> watchMatchEvents(String matchId) async* {
    final client = _connection.client;
    if (client == null) {
      yield const [];
      return;
    }

    try {
      final rows = await client
          .from('match_events')
          .select()
          .eq('match_id', matchId)
          .order('minute');
      yield (rows as List)
          .whereType<Map>()
          .map((row) => MatchEventModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load match events: $error');
      yield const [];
    }
  }

  @override
  Future<MatchAiAnalysis?> getMatchAiAnalysis(String matchId) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('match_ai_analysis')
          .select()
          .eq('match_id', matchId)
          .order('generated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null
          ? null
          : MatchAiAnalysis.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load match AI analysis: $error');
      return null;
    }
  }
}

List<MatchModel> _applyFilter(List<MatchModel> matches, MatchesFilter filter) {
  final dateFrom = filter.dateFrom == null
      ? null
      : DateTime.tryParse(filter.dateFrom!);
  final dateTo = filter.dateTo == null ? null : DateTime.tryParse(filter.dateTo!);

  var filtered = matches
      .where((match) {
        if (filter.competitionId != null &&
            match.competitionId != filter.competitionId) {
          return false;
        }
        if (filter.teamId != null &&
            match.homeTeamId != filter.teamId &&
            match.awayTeamId != filter.teamId) {
          return false;
        }
        if (filter.status != null &&
            match.normalizedStatus != filter.status!.trim().toLowerCase()) {
          return false;
        }
        if (dateFrom != null && match.date.isBefore(dateFrom)) {
          return false;
        }
        if (dateTo != null && match.date.isAfter(dateTo)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);

  filtered = [...filtered]
    ..sort(
      (left, right) => filter.ascending
          ? left.date.compareTo(right.date)
          : right.date.compareTo(left.date),
    );

  if (filtered.length > filter.limit) {
    filtered = filtered.take(filter.limit).toList(growable: false);
  }
  return filtered;
}

MatchOddsModel _fallbackOdds(String matchId) {
  return MatchOddsModel(
    matchId: matchId,
    homeMultiplier: 1.8,
    drawMultiplier: 3.4,
    awayMultiplier: 4.1,
    provider: 'fallback',
    refreshedAt: DateTime.now(),
  );
}

List<MatchModel> _fallbackMatches() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    MatchModel(
      id: 'match_live_1',
      competitionId: 'epl',
      season: '2025/26',
      date: today,
      kickoffTime: '20:00',
      homeTeamId: 'liverpool',
      awayTeamId: 'arsenal',
      homeTeam: 'Liverpool',
      awayTeam: 'Arsenal',
      ftHome: 2,
      ftAway: 1,
      status: 'live',
      dataSource: 'fallback',
    ),
    MatchModel(
      id: 'match_upcoming_1',
      competitionId: 'laliga',
      season: '2025/26',
      date: today,
      kickoffTime: '21:00',
      homeTeamId: 'barcelona',
      awayTeamId: 'real-madrid',
      homeTeam: 'Barcelona',
      awayTeam: 'Real Madrid',
      status: 'upcoming',
      dataSource: 'fallback',
    ),
    MatchModel(
      id: 'match_finished_1',
      competitionId: 'epl',
      season: '2025/26',
      date: today.subtract(const Duration(days: 1)),
      kickoffTime: '18:00',
      homeTeamId: 'manchester-city',
      awayTeamId: 'manchester-united',
      homeTeam: 'Manchester City',
      awayTeam: 'Manchester United',
      ftHome: 3,
      ftAway: 2,
      status: 'finished',
      dataSource: 'fallback',
    ),
  ];
}
