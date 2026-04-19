import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import 'team_search_catalog.dart';

abstract class OnboardingGateway {
  List<OnboardingTeam> get allTeams;

  List<OnboardingTeam> searchTeams(String query, {int limit = 10});

  List<OnboardingTeam> popularTeamsForRegion(String region);

  Future<void> saveOnboardingTeams({
    OnboardingTeam? localTeam,
    Set<String> popularTeamIds = const <String>{},
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

@LazySingleton(as: OnboardingGateway)
class SupabaseOnboardingGateway implements OnboardingGateway {
  SupabaseOnboardingGateway(this._catalog, this._cache, this._connection);

  static const _favoriteTeamsCacheKey = 'favorite_teams_cache_v1';

  final TeamSearchCatalog _catalog;
  final CacheService _cache;
  final SupabaseConnection _connection;

  @override
  List<OnboardingTeam> get allTeams => _catalog.allTeams;

  @override
  List<OnboardingTeam> searchTeams(String query, {int limit = 10}) {
    return _catalog.search(query, limit: limit);
  }

  @override
  List<OnboardingTeam> popularTeamsForRegion(String region) {
    return _catalog.popularForRegion(region);
  }

  @override
  Future<void> saveOnboardingTeams({
    OnboardingTeam? localTeam,
    Set<String> popularTeamIds = const <String>{},
  }) async {
    final rows = <FavoriteTeamRecordDto>[];

    if (localTeam != null) {
      rows.add(_teamToRecord(localTeam, source: 'local', sortOrder: 0));
    }

    var sortOrder = 0;
    for (final teamId in popularTeamIds) {
      final team = _catalog.byId(teamId);
      if (team == null) continue;
      rows.add(_teamToRecord(team, source: 'popular', sortOrder: sortOrder));
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

    return cached
        .map(FavoriteTeamRecordDto.fromJson)
        .toList(growable: false);
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
            (row) => FavoriteTeamRecordDto.fromJson(
              Map<String, dynamic>.from(row),
            ),
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
      profilePatch['region'] = _inferRegion(nextCountryCode);
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

  String _inferRegion(String countryCode) {
    final code = countryCode.toUpperCase();
    const african = {
      'RW',
      'NG',
      'KE',
      'ZA',
      'EG',
      'TZ',
      'UG',
      'GH',
      'TN',
      'DZ',
      'MA',
      'CD',
      'SN',
      'CI',
      'ML',
      'BF',
      'NE',
      'TG',
      'BJ',
      'GW',
      'ET',
      'CM',
    };
    const northAmerican = {'US', 'CA', 'MX'};

    if (african.contains(code)) return 'africa';
    if (northAmerican.contains(code)) return 'north_america';
    return 'europe';
  }
}
