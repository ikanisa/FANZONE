import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/team_search_database.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';

abstract class OnboardingGateway {
  List<OnboardingTeam> get allTeams;

  List<OnboardingTeam> searchTeams(String query, {int limit = 10});

  List<OnboardingTeam> searchPopularTeams(String query, {int limit = 10});

  List<OnboardingTeam> popularTeamsForRegion(String region);

  Future<void> saveOnboardingTeams({
    OnboardingTeam? localTeam,
    Set<String> popularTeamIds = const <String>{},
  });

  Future<void> saveFanProfileTeams({
    OnboardingTeam? localTeam,
    Set<String> topEuropeanTeamIds = const <String>{},
    Set<String> nationalTeamIds = const <String>{},
  });

  Future<void> addFavoriteTeam(
    OnboardingTeam team, {
    String source = 'settings',
  });

  Future<void> syncCachedTeamsIfAuthenticated();

  Future<List<FavoriteTeamRecordDto>> getCachedFavoriteTeams();

  Future<List<FavoriteTeamRecordDto>> getUserFavoriteTeams();

  Future<void> deleteFavoriteTeam(String teamId);
}

class SupabaseOnboardingGateway implements OnboardingGateway {
  SupabaseOnboardingGateway(this._catalog, this._cache, this._connection);

  static const _favoriteTeamsCacheKey = 'favorite_teams_cache_v1';

  final TeamSearchCatalog _catalog;
  final CacheService _cache;
  final SupabaseConnection _connection;

  TeamSearchCatalog get _resolvedCatalog {
    final liveCatalog = activeTeamSearchCatalog;
    if (liveCatalog.allTeams.isNotEmpty) return liveCatalog;
    return _catalog;
  }

  @override
  List<OnboardingTeam> get allTeams => _resolvedCatalog.allTeams;

  @override
  List<OnboardingTeam> searchTeams(String query, {int limit = 10}) {
    return _resolvedCatalog.searchLocal(query, limit: limit);
  }

  @override
  List<OnboardingTeam> searchPopularTeams(String query, {int limit = 10}) {
    return _resolvedCatalog.searchPopular(query, limit: limit);
  }

  @override
  List<OnboardingTeam> popularTeamsForRegion(String region) {
    return _resolvedCatalog.popularForRegion(region);
  }

  @override
  Future<void> saveOnboardingTeams({
    OnboardingTeam? localTeam,
    Set<String> popularTeamIds = const <String>{},
  }) async {
    await saveFanProfileTeams(
      localTeam: localTeam,
      topEuropeanTeamIds: popularTeamIds,
    );
  }

  @override
  Future<void> saveFanProfileTeams({
    OnboardingTeam? localTeam,
    Set<String> topEuropeanTeamIds = const <String>{},
    Set<String> nationalTeamIds = const <String>{},
  }) async {
    validateFanProfileSelection(
      localTeam: localTeam,
      topEuropeanTeamIds: topEuropeanTeamIds,
      nationalTeamIds: nationalTeamIds,
    );

    final rows = <FavoriteTeamRecordDto>[];
    final usedTeamIds = <String>{};
    final cachedById = {
      for (final row in await getCachedFavoriteTeams()) row.teamId: row,
    };

    if (localTeam != null) {
      rows.add(_teamToRecord(localTeam, source: 'local', sortOrder: 0));
      usedTeamIds.add(localTeam.id);
    }

    var sortOrder = 10;
    for (final teamId in topEuropeanTeamIds) {
      if (usedTeamIds.contains(teamId)) continue;
      final row = _favoriteRecordForTeamId(
        teamId,
        cachedById: cachedById,
        source: FanProfileTeamCategory.topEuropean.source,
        sortOrder: sortOrder,
      );
      if (row == null) continue;
      rows.add(row);
      usedTeamIds.add(teamId);
      sortOrder += 1;
    }

    sortOrder = 20;
    for (final teamId in nationalTeamIds) {
      if (usedTeamIds.contains(teamId)) continue;
      final row = _favoriteRecordForTeamId(
        teamId,
        cachedById: cachedById,
        source: FanProfileTeamCategory.national.source,
        sortOrder: sortOrder,
      );
      if (row == null) continue;
      rows.add(row);
      usedTeamIds.add(teamId);
      sortOrder += 1;
    }

    await _writeCachedTeams(rows);
    await _syncTeamsToSupabase(
      rows,
      replaceRemote: true,
      onboardingCompleted: true,
    );
  }

  @override
  Future<void> addFavoriteTeam(
    OnboardingTeam team, {
    String source = 'settings',
  }) async {
    final cached = await getCachedFavoriteTeams();
    final next = [
      for (final row in cached)
        if (row.teamId != team.id) row,
      _teamToRecord(team, source: source, sortOrder: cached.length),
    ];

    await _writeCachedTeams(next);
    await _syncTeamsToSupabase(
      next,
      replaceRemote: false,
      onboardingCompleted: null,
    );
  }

  @override
  Future<void> syncCachedTeamsIfAuthenticated() async {
    final client = _connection.client;
    final userId = _connection.currentUser?.id;
    if (client == null || userId == null) return;

    final cached = await getCachedFavoriteTeams();
    if (cached.isEmpty) return;

    try {
      final existing = await client
          .from('user_favorite_teams')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      if ((existing as List).isEmpty) {
        await _upsertFavoriteRows(client, userId, cached, replaceRemote: false);
        await _updateProfileSummary(
          client,
          userId,
          cached,
          onboardingCompleted: true,
        );
      }
    } catch (error) {
      AppLogger.d('Failed to sync cached teams: $error');
    }
  }

  @override
  Future<List<FavoriteTeamRecordDto>> getCachedFavoriteTeams() async {
    final cached = await _cache.getJsonList(
      _favoriteTeamsCacheKey,
      debugLabel: 'favorite teams',
    );

    return cached.map(FavoriteTeamRecordDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<FavoriteTeamRecordDto>> getUserFavoriteTeams() async {
    final cached = await getCachedFavoriteTeams();

    final client = _connection.client;
    final userId = _connection.currentUser?.id;
    if (client == null || userId == null) return cached;

    try {
      await syncCachedTeamsIfAuthenticated();

      final data = await client
          .from('user_favorite_teams')
          .select()
          .eq('user_id', userId)
          .order('source')
          .order('sort_order')
          .order('created_at');

      final remoteRows = (data as List)
          .map(
            (row) =>
                FavoriteTeamRecordDto.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      if (remoteRows.isNotEmpty) {
        await _writeCachedTeams(remoteRows);
        return remoteRows;
      }
    } catch (error) {
      AppLogger.d('Failed to fetch favorite teams: $error');
    }

    return cached;
  }

  @override
  Future<void> deleteFavoriteTeam(String teamId) async {
    final cached = await getCachedFavoriteTeams();
    final next = cached.where((row) => row.teamId != teamId).toList();

    await _writeCachedTeams(next);

    final client = _connection.client;
    final userId = _connection.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client
          .from('user_favorite_teams')
          .delete()
          .eq('user_id', userId)
          .eq('team_id', teamId);

      await _updateProfileSummary(
        client,
        userId,
        next,
        onboardingCompleted: null,
      );
    } catch (error) {
      AppLogger.d('Failed to delete favorite team: $error');
    }
  }

  FavoriteTeamRecordDto _teamToRecord(
    OnboardingTeam team, {
    required String source,
    required int sortOrder,
  }) {
    return FavoriteTeamRecordDto(
      teamId: team.id,
      teamName: team.name,
      teamShortName: team.shortName,
      teamCountry: team.country,
      teamCountryCode: team.countryCode,
      teamLeague: team.league,
      teamCrestUrl: team.resolvedCrestUrl,
      source: source,
      sortOrder: sortOrder,
      updatedAt: DateTime.now(),
    );
  }

  FavoriteTeamRecordDto? _favoriteRecordForTeamId(
    String teamId, {
    required Map<String, FavoriteTeamRecordDto> cachedById,
    required String source,
    required int sortOrder,
  }) {
    final team = _resolvedCatalog.byId(teamId);
    if (team != null) {
      return _teamToRecord(team, source: source, sortOrder: sortOrder);
    }

    final cached = cachedById[teamId];
    if (cached == null) return null;

    return FavoriteTeamRecordDto(
      teamId: cached.teamId,
      teamName: cached.teamName,
      teamShortName: cached.teamShortName,
      teamCountry: cached.teamCountry,
      teamCountryCode: cached.teamCountryCode,
      teamLeague: cached.teamLeague,
      teamCrestUrl: cached.teamCrestUrl,
      source: source,
      sortOrder: sortOrder,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _writeCachedTeams(List<FavoriteTeamRecordDto> rows) async {
    await _cache.setJson(
      _favoriteTeamsCacheKey,
      rows.map((row) => row.toJson()).toList(growable: false),
    );
  }

  Future<void> _syncTeamsToSupabase(
    List<FavoriteTeamRecordDto> rows, {
    required bool replaceRemote,
    required bool? onboardingCompleted,
  }) async {
    final client = _connection.client;
    final userId = _connection.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await _upsertFavoriteRows(
        client,
        userId,
        rows,
        replaceRemote: replaceRemote,
      );
      await _updateProfileSummary(
        client,
        userId,
        rows,
        onboardingCompleted: onboardingCompleted,
      );
    } catch (error) {
      AppLogger.d('Failed to sync onboarding teams: $error');
    }
  }

  Future<void> _upsertFavoriteRows(
    SupabaseClient client,
    String userId,
    List<FavoriteTeamRecordDto> rows, {
    required bool replaceRemote,
  }) async {
    if (replaceRemote) {
      await client.from('user_favorite_teams').delete().eq('user_id', userId);
    }

    if (rows.isEmpty) return;

    final payload = rows
        .asMap()
        .entries
        .map(
          (entry) => {
            ...entry.value.toJson(),
            'user_id': userId,
            'sort_order': entry.value.sortOrder,
            'updated_at': DateTime.now().toIso8601String(),
          },
        )
        .toList(growable: false);

    await client
        .from('user_favorite_teams')
        .upsert(payload, onConflict: 'user_id,team_id');
  }

  Future<void> _updateProfileSummary(
    SupabaseClient client,
    String userId,
    List<FavoriteTeamRecordDto> rows, {
    required bool? onboardingCompleted,
  }) async {
    final local = rows.where((row) => row.source == 'local').firstOrNull;
    final primary = local ?? rows.firstOrNull;
    final nextCountryCode = primary?.teamCountryCode;

    final profilePatch = <String, dynamic>{
      'id': userId,
      'user_id': userId,
      'favorite_team_id': primary?.teamId,
      'favorite_team_name': primary?.teamName,
      'display_name': null,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (nextCountryCode != null && nextCountryCode.isNotEmpty) {
      profilePatch['active_country'] = nextCountryCode;
      profilePatch['country_code'] = nextCountryCode;
      profilePatch['region'] = await _inferRegion(client, nextCountryCode);
    }

    if (onboardingCompleted != null) {
      profilePatch['onboarding_completed'] = onboardingCompleted;
    }

    await client.from('profiles').upsert(profilePatch, onConflict: 'id');

    try {
      await client.rpc('guess_user_currency', params: {'p_user_id': userId});
    } catch (error) {
      AppLogger.d('Failed to refresh inferred currency: $error');
    }
  }

  Future<String> _inferRegion(SupabaseClient client, String countryCode) async {
    final normalizedCode = countryCode.trim().toUpperCase();

    try {
      final result = await client
          .rpc('get_country_region', params: {'p_country_code': countryCode})
          .timeout(const Duration(seconds: 5));
      if (result is String && result.isNotEmpty) return result;
    } catch (_) {
      // Fall through to direct table lookup.
    }

    try {
      final row = await client
          .from('country_region_map')
          .select('region')
          .eq('country_code', normalizedCode)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      final region = row?['region']?.toString();
      if (region != null && region.isNotEmpty) return region;
    } catch (_) {
      // Ignore and fall back to the neutral region below.
    }

    return 'global';
  }
}
