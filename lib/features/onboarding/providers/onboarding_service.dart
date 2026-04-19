import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/preferences_json_store.dart';
import '../../../data/team_search_database.dart';
import '../../../main.dart' show supabaseInitialized;

/// Persistence service for onboarding and favorite-team preferences.
///
/// Team selections are always cached locally so onboarding works for guests.
/// When a session exists, the same data is synced to Supabase and used for
/// backend currency inference.
class OnboardingService {
  static const _favoriteTeamsCacheKey = 'favorite_teams_cache_v1';

  static Future<void> saveOnboardingTeams({
    OnboardingTeam? localTeam,
    Set<String> popularTeamIds = const {},
  }) async {
    final rows = <Map<String, dynamic>>[];

    if (localTeam != null) {
      rows.add(_teamToRow(localTeam, source: 'local', sortOrder: 0));
    }

    var sortOrder = 0;
    for (final teamId in popularTeamIds) {
      final team = allTeams
          .where((candidate) => candidate.id == teamId)
          .firstOrNull;
      if (team == null) continue;
      rows.add(_teamToRow(team, source: 'popular', sortOrder: sortOrder));
      sortOrder += 1;
    }

    await _writeCachedTeams(rows);
    await _syncTeamsToSupabase(
      rows,
      replaceRemote: true,
      onboardingCompleted: true,
    );
  }

  static Future<void> addFavoriteTeam(
    OnboardingTeam team, {
    String source = 'settings',
  }) async {
    final cached = await getCachedFavoriteTeams();
    final next = [
      for (final row in cached)
        if (row['team_id']?.toString() != team.id) row,
      _teamToRow(team, source: source, sortOrder: cached.length),
    ];

    await _writeCachedTeams(next);
    await _syncTeamsToSupabase(
      next,
      replaceRemote: false,
      onboardingCompleted: null,
    );
  }

  static Future<void> syncCachedTeamsIfAuthenticated() async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

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

  static Future<List<Map<String, dynamic>>> getCachedFavoriteTeams() async {
    return PreferencesJsonStore.readList(
      _favoriteTeamsCacheKey,
      debugLabel: 'favorite teams',
    );
  }

  static Future<List<Map<String, dynamic>>> getUserFavoriteTeams() async {
    final cached = await getCachedFavoriteTeams();

    if (!supabaseInitialized) return cached;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return cached;

    try {
      await syncCachedTeamsIfAuthenticated();

      final data = await client
          .from('user_favorite_teams')
          .select()
          .eq('user_id', userId)
          .order('source')
          .order('sort_order')
          .order('created_at');

      final remoteRows = List<Map<String, dynamic>>.from(data as List);
      if (remoteRows.isNotEmpty) {
        await _writeCachedTeams(remoteRows);
        return remoteRows;
      }
    } catch (error) {
      AppLogger.d('Failed to fetch favorite teams: $error');
    }

    return cached;
  }

  static Future<void> deleteFavoriteTeam(String teamId) async {
    final cached = await getCachedFavoriteTeams();
    final next = cached
        .where((row) => row['team_id']?.toString() != teamId)
        .toList();

    await _writeCachedTeams(next);

    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

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

  static Map<String, dynamic> _teamToRow(
    OnboardingTeam team, {
    required String source,
    required int sortOrder,
  }) {
    return {
      'team_id': team.id,
      'team_name': team.name,
      'team_short_name': team.shortName,
      'team_country': team.country,
      'team_country_code': team.countryCode,
      'team_league': team.league,
      'team_crest_url': team.resolvedCrestUrl,
      'source': source,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> _writeCachedTeams(List<Map<String, dynamic>> rows) async {
    await PreferencesJsonStore.write(_favoriteTeamsCacheKey, rows);
  }

  static Future<void> _syncTeamsToSupabase(
    List<Map<String, dynamic>> rows, {
    required bool replaceRemote,
    required bool? onboardingCompleted,
  }) async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

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

  static Future<void> _upsertFavoriteRows(
    SupabaseClient client,
    String userId,
    List<Map<String, dynamic>> rows, {
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
            ...entry.value,
            'user_id': userId,
            'sort_order': entry.value['sort_order'] ?? entry.key,
            'updated_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();

    await client
        .from('user_favorite_teams')
        .upsert(payload, onConflict: 'user_id,team_id');
  }

  static Future<void> _updateProfileSummary(
    SupabaseClient client,
    String userId,
    List<Map<String, dynamic>> rows, {
    required bool? onboardingCompleted,
  }) async {
    final local = rows.where((row) => row['source'] == 'local').firstOrNull;
    final primary = local ?? rows.firstOrNull;
    final nextCountryCode = primary?['team_country_code']?.toString();

    final profilePatch = <String, dynamic>{
      'id': userId,
      'user_id': userId,
      'favorite_team_id': primary?['team_id'],
      'favorite_team_name': primary?['team_name'],
      'display_name': null,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (nextCountryCode != null && nextCountryCode.isNotEmpty) {
      profilePatch['active_country'] = nextCountryCode;
      profilePatch['country_code'] = nextCountryCode;

      // Infer region from country code
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

  /// Infer user region from their primary team's country code.
  static String _inferRegion(String countryCode) {
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
