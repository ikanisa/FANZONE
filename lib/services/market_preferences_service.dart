import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../core/storage/preferences_json_store.dart';
import '../main.dart' show supabaseInitialized;
import '../models/user_market_preferences_model.dart';

class MarketPreferencesService {
  static const _cacheKey = 'user_market_preferences_cache_v1';

  static Future<UserMarketPreferences> getCachedPreferences() async {
    final cached = await PreferencesJsonStore.readMap(
      _cacheKey,
      debugLabel: 'market preferences',
    );
    if (cached == null) return UserMarketPreferences.defaults;
    return UserMarketPreferences.fromJson(cached);
  }

  static Future<UserMarketPreferences> getUserPreferences() async {
    final cached = await getCachedPreferences();

    if (!supabaseInitialized) return cached;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return cached;

    try {
      final data = await client
          .from('user_market_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        final resolved = UserMarketPreferences.fromJson(data);
        await _writeCache(resolved);
        return resolved;
      }

      if (cached.hasCustomSelections) {
        await _upsertPreferences(client, userId, cached);
      }
    } catch (error) {
      AppLogger.d('Failed to fetch market preferences: $error');
    }

    return cached;
  }

  static Future<void> saveUserPreferences(
    UserMarketPreferences preferences,
  ) async {
    final normalized = preferences.copyWith(updatedAt: DateTime.now());
    await _writeCache(normalized);

    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _upsertPreferences(client, userId, normalized);
    } catch (error) {
      AppLogger.d('Failed to save market preferences: $error');
    }
  }

  static Future<void> syncCachedPreferencesIfAuthenticated() async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final cached = await getCachedPreferences();
    if (!cached.hasCustomSelections) return;

    try {
      final existing = await client
          .from('user_market_preferences')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _upsertPreferences(client, userId, cached);
      }
    } catch (error) {
      AppLogger.d('Failed to sync cached market preferences: $error');
    }
  }

  static Future<void> _writeCache(UserMarketPreferences preferences) async {
    await PreferencesJsonStore.write(_cacheKey, preferences.toJson());
  }

  static Future<void> _upsertPreferences(
    SupabaseClient client,
    String userId,
    UserMarketPreferences preferences,
  ) async {
    final payload = {'user_id': userId, ...preferences.toJson()};

    await client
        .from('user_market_preferences')
        .upsert(payload, onConflict: 'user_id');

    await client.from('profiles').upsert({
      'id': userId,
      'user_id': userId,
      'region': preferences.primaryRegion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }
}
