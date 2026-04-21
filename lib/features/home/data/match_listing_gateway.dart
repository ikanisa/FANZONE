import '../../../core/cache/stale_while_revalidate.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/match_model.dart';
import 'home_dtos.dart';
import 'matches_gateway_shared.dart';
import 'sports_data_exception.dart';

abstract interface class MatchListingGateway {
  Future<List<MatchModel>> getMatches(MatchesFilter filter);

  Stream<MatchModel?> watchMatch(String matchId);

  Stream<List<MatchModel>> watchMatchesByDate(DateTime date);

  Stream<List<MatchModel>> watchCompetitionMatches(String competitionId);

  Stream<List<MatchModel>> watchTeamMatches(String teamId);

  Stream<List<MatchModel>> watchUpcomingMatches();

  /// Watches currently live matches via the `get_live_matches()` RPC.
  Stream<List<MatchModel>> watchLiveMatches();
}

class SupabaseMatchListingGateway implements MatchListingGateway {
  SupabaseMatchListingGateway(this._connection);

  final SupabaseConnection _connection;

  static const _matchCacheTtl = Duration(minutes: 5);

  String _dateCacheKey(String dateFrom, String dateTo) =>
      'matches:$dateFrom:$dateTo';

  Never _throwUnavailable(String operation) {
    throw SportsDataUnavailableException(
      'Sports data is unavailable for $operation.',
    );
  }

  @override
  Future<List<MatchModel>> getMatches(MatchesFilter filter) async {
    if (_connection.client == null) {
      _throwUnavailable('match loading');
    }

    if (_isCompetitionOnlyFilter(filter)) {
      return _fetchCompetitionMatches(
        filter.competitionId!,
        limit: filter.limit,
      );
    }

    if (_isTeamOnlyFilter(filter)) {
      return _fetchTeamMatches(filter.teamId!, limit: filter.limit);
    }

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
        return _parseMatchRows(cachedRows);
      } catch (_) {
        // Fall through to direct fetch
      }
    }

    try {
      final rows = await _fetchMatchRows(filter);
      return _parseMatchRows(rows);
    } catch (error) {
      AppLogger.d('Failed to load matches: $error');
      if (error is SportsDataException) rethrow;
      throw SportsDataQueryException('Failed to load matches.', cause: error);
    }
  }

  bool _isCompetitionOnlyFilter(MatchesFilter filter) {
    return filter.competitionId != null &&
        filter.competitionId!.isNotEmpty &&
        filter.teamId == null &&
        filter.status == null &&
        filter.dateFrom == null &&
        filter.dateTo == null;
  }

  bool _isTeamOnlyFilter(MatchesFilter filter) {
    return filter.teamId != null &&
        filter.teamId!.isNotEmpty &&
        filter.competitionId == null &&
        filter.status == null &&
        filter.dateFrom == null &&
        filter.dateTo == null;
  }

  String? _singleDayFilterValue(MatchesFilter filter) {
    final from = filter.dateFrom;
    final to = filter.dateTo;
    if (from == null || to == null) return null;

    final fromDay = from.split('T').first;
    final toDay = to.split('T').first;
    if (fromDay != toDay || fromDay.isEmpty) return null;

    return fromDay;
  }

  List<MatchModel> _parseMatchRows(dynamic rows) {
    return (rows as List)
        .whereType<Map>()
        .map((row) => MatchModel.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<MatchModel>> _fetchCompetitionMatches(
    String competitionId, {
    int limit = 500,
  }) async {
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('competition fixtures');
    }

    try {
      final rows = await client.rpc(
        'app_competition_matches',
        params: {'p_competition_id': competitionId, 'p_limit': limit},
      );
      return _parseMatchRows(rows);
    } catch (error) {
      AppLogger.d('Failed to load competition matches via RPC: $error');
      try {
        final rows = await client
            .from('matches_live_view')
            .select()
            .eq('competition_id', competitionId)
            .order('date', ascending: false)
            .limit(limit);
        return _parseMatchRows(rows);
      } catch (fallbackError) {
        AppLogger.d(
          'Failed to load competition matches via fallback query: $fallbackError',
        );
        throw SportsDataQueryException(
          'Failed to load competition fixtures for $competitionId.',
          cause: fallbackError,
        );
      }
    }
  }

  Future<List<MatchModel>> _fetchTeamMatches(
    String teamId, {
    int limit = 120,
  }) async {
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('team fixtures');
    }

    try {
      final rows = await client.rpc(
        'app_team_matches',
        params: {'p_team_id': teamId, 'p_limit': limit},
      );
      return _parseMatchRows(rows);
    } catch (error) {
      AppLogger.d('Failed to load team matches via RPC: $error');
      try {
        final rows = await client
            .from('matches_live_view')
            .select()
            .or('home_team_id.eq.$teamId,away_team_id.eq.$teamId')
            .order('date', ascending: false)
            .limit(limit);
        return _parseMatchRows(rows);
      } catch (fallbackError) {
        AppLogger.d(
          'Failed to load team matches via fallback query: $fallbackError',
        );
        throw SportsDataQueryException(
          'Failed to load team fixtures for $teamId.',
          cause: fallbackError,
        );
      }
    }
  }

  /// Raw Supabase query — returns deserialization-ready maps.
  Future<List<Map<String, dynamic>>> _fetchMatchRows(
    MatchesFilter filter,
  ) async {
    final client = _connection.client!;
    final singleDay = _singleDayFilterValue(filter);

    if (singleDay != null &&
        filter.teamId == null &&
        filter.status == null &&
        filter.competitionId == null) {
      try {
        final rows = await client.rpc(
          'app_matches_by_date',
          params: {'p_date': singleDay},
        );
        return (rows as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false);
      } catch (error) {
        AppLogger.d('Failed to load matches by date via RPC: $error');
      }
    }

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
        .order('kickoff_time', ascending: filter.ascending)
        .limit(filter.limit);

    return (rows as List)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  @override
  Stream<MatchModel?> watchMatch(String matchId) {
    return pollMatchStream<MatchModel?>(() async {
      final client = _connection.client;
      if (client == null) {
        _throwUnavailable('match details');
      }

      try {
        final row = await client
            .from('matches_live_view')
            .select()
            .eq('id', matchId)
            .maybeSingle();
        if (row == null) return null;
        return MatchModel.fromJson(
          Map<String, dynamic>.from(row as Map<dynamic, dynamic>),
        );
      } catch (error) {
        AppLogger.d('Failed to load match $matchId: $error');
        throw SportsDataQueryException(
          'Failed to load match details for $matchId.',
          cause: error,
        );
      }
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
      () => _fetchCompetitionMatches(competitionId, limit: 500),
    );
  }

  @override
  Stream<List<MatchModel>> watchTeamMatches(String teamId) {
    return pollMatchStream<List<MatchModel>>(
      () => _fetchTeamMatches(teamId, limit: 120),
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

  @override
  Stream<List<MatchModel>> watchLiveMatches() {
    return pollMatchStream<List<MatchModel>>(() async {
      final client = _connection.client;
      if (client == null) {
        _throwUnavailable('live matches');
      }

      try {
        final rows = await client.rpc('get_live_matches');
        return _parseMatchRows(rows);
      } catch (error) {
        AppLogger.d('Failed to load live matches via RPC: $error');
        // Fallback to view-based query
        return getMatches(
          const MatchesFilter(status: 'live', limit: 100, ascending: true),
        );
      }
    });
  }
}
