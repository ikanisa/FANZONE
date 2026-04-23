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

  /// Watches currently live matches from the lean `app_matches` projection.
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

  List<MatchModel> _parseMatchRows(dynamic rows) {
    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => MatchModel.fromJson(
            _normalizeMatchRow(Map<String, dynamic>.from(row)),
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _normalizeMatchRow(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    final rawStatus =
        row['status']?.toString() ?? row['match_status']?.toString() ?? '';
    normalized['competition_name'] = row['competition_name']?.toString();
    normalized['season_id'] = row['season_id']?.toString();
    normalized['season_label'] =
        row['season_label']?.toString() ?? row['season']?.toString() ?? '';
    normalized['match_date'] = row['match_date'] ?? row['date'];
    normalized['round'] =
        row['round']?.toString() ?? row['matchday_or_round']?.toString();
    normalized['matchday_or_round'] =
        row['matchday_or_round']?.toString() ?? row['round']?.toString();
    normalized['live_minute'] = (row['live_minute'] as num?)?.toInt();
    normalized['stage'] = row['stage']?.toString();
    normalized['result_code'] = row['result_code']?.toString();
    normalized['is_neutral'] = row['is_neutral'] == true;
    normalized['notes'] = row['notes']?.toString();
    normalized['status'] = _normalizeStatus(rawStatus);
    normalized['data_source'] =
        row['data_source']?.toString() ??
        row['source_name']?.toString() ??
        'manual';
    normalized['ft_home'] =
        row['live_home_score'] ?? row['ft_home'] ?? row['home_goals'];
    normalized['ft_away'] =
        row['live_away_score'] ?? row['ft_away'] ?? row['away_goals'];
    normalized['home_logo_url'] =
        row['home_logo_url']?.toString() ?? row['home_crest_url']?.toString();
    normalized['away_logo_url'] =
        row['away_logo_url']?.toString() ?? row['away_crest_url']?.toString();
    return normalized;
  }

  String _normalizeStatus(String status) {
    final value = status.trim().toLowerCase();
    switch (value) {
      case 'scheduled':
      case 'not_started':
      case 'pending':
        return 'upcoming';
      case 'in_play':
      case 'in_progress':
        return 'live';
      case 'complete':
      case 'completed':
      case 'full_time':
        return 'finished';
      default:
        return value.isEmpty ? 'upcoming' : value;
    }
  }

  List<String>? _statusValues(String? status) {
    final value = status?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;

    switch (value) {
      case 'live':
        return const ['live', 'in_play', 'in_progress', 'playing'];
      case 'finished':
        return const ['finished', 'complete', 'completed', 'full_time', 'ft'];
      case 'upcoming':
      case 'scheduled':
        return const ['scheduled', 'not_started', 'pending', 'upcoming'];
      default:
        return [value];
    }
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
      final rows = await client
          .from('app_matches')
          .select()
          .eq('competition_id', competitionId)
          .order('date', ascending: false)
          .limit(limit);
      return _parseMatchRows(rows);
    } catch (error) {
      AppLogger.d('Failed to load competition matches: $error');
      throw SportsDataQueryException(
        'Failed to load competition fixtures for $competitionId.',
        cause: error,
      );
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
      final rows = await client
          .from('app_matches')
          .select()
          .or('home_team_id.eq.$teamId,away_team_id.eq.$teamId')
          .order('date', ascending: false)
          .limit(limit);
      return _parseMatchRows(rows);
    } catch (error) {
      AppLogger.d('Failed to load team matches: $error');
      throw SportsDataQueryException(
        'Failed to load team fixtures for $teamId.',
        cause: error,
      );
    }
  }

  /// Raw Supabase query — returns deserialization-ready maps.
  Future<List<Map<String, dynamic>>> _fetchMatchRows(
    MatchesFilter filter,
  ) async {
    final client = _connection.client!;
    var query = client.from('app_matches').select();
    if (filter.competitionId != null && filter.competitionId!.isNotEmpty) {
      query = query.eq('competition_id', filter.competitionId!);
    }
    if (filter.teamId != null && filter.teamId!.isNotEmpty) {
      query = query.or(
        'home_team_id.eq.${filter.teamId},away_team_id.eq.${filter.teamId}',
      );
    }
    final statusValues = _statusValues(filter.status);
    if (statusValues != null) {
      query = query.inFilter('status', statusValues);
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
            .from('app_matches')
            .select()
            .eq('id', matchId)
            .maybeSingle();
        if (row == null) return null;
        return MatchModel.fromJson(
          _normalizeMatchRow(Map<String, dynamic>.from(row as Map)),
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
    return pollMatchStream<List<MatchModel>>(
      () => getMatches(
        const MatchesFilter(status: 'live', limit: 100, ascending: true),
      ),
    );
  }
}
