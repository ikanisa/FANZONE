import '../../../core/cache/stale_while_revalidate.dart';
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

  static const _matchCacheTtl = Duration(minutes: 5);

  String _dateCacheKey(String dateFrom, String dateTo) =>
      'matches:$dateFrom:$dateTo';

  @override
  Future<List<MatchModel>> getMatches(MatchesFilter filter) async {
    final client = _connection.client;
    if (client == null) return const <MatchModel>[];

    // Build a cache key for date-filtered queries
    final useSWR =
        filter.dateFrom != null &&
        filter.dateTo != null &&
        filter.competitionId == null &&
        filter.teamId == null &&
        filter.status == null;

    if (useSWR) {
      try {
        final cacheKey = _dateCacheKey(filter.dateFrom!, filter.dateTo!);
        final cachedRows = await StaleWhileRevalidateCache.list(
          cacheKey: cacheKey,
          ttl: _matchCacheTtl,
          fetch: () => _fetchMatchRows(filter),
        );
        return cachedRows.map(MatchModel.fromJson).toList(growable: false);
      } catch (_) {
        // Fall through to direct fetch
      }
    }

    try {
      final rows = await _fetchMatchRows(filter);
      return rows.map(MatchModel.fromJson).toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load matches: $error');
      return const <MatchModel>[];
    }
  }

  /// Raw Supabase query — returns deserialization-ready maps.
  Future<List<Map<String, dynamic>>> _fetchMatchRows(
    MatchesFilter filter,
  ) async {
    final client = _connection.client!;

    var query = client.from('matches_live_view').select();
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

    return (rows as List)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
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

    // Pre-fetch adjacent dates (±1 day) for instant date-ribbon swiping.
    _prefetchAdjacentDates(date);

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

  /// Pre-fetches match data for the day before and after [date].
  void _prefetchAdjacentDates(DateTime date) {
    final yesterday = date.subtract(const Duration(days: 1));
    final tomorrow = date.add(const Duration(days: 1));

    final adjacentKeys = [yesterday, tomorrow].map((d) {
      final start = DateTime(d.year, d.month, d.day).toIso8601String();
      final end = DateTime(
        d.year,
        d.month,
        d.day,
        23,
        59,
        59,
      ).toIso8601String();
      return _dateCacheKey(start, end);
    }).toList();

    StaleWhileRevalidateCache.prefetchAdjacent(
      cacheKeys: adjacentKeys,
      ttl: _matchCacheTtl,
      fetch: (key) {
        // Parse dates back from the cache key
        final parts = key.split(':');
        if (parts.length < 3) return Future.value([]);
        return _fetchMatchRows(
          MatchesFilter(
            dateFrom: parts[1],
            dateTo: parts[2],
            limit: 200,
            ascending: true,
          ),
        );
      },
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
