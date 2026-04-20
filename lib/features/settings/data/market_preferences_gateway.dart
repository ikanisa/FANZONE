import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/user_market_preferences_model.dart';

abstract interface class MarketPreferencesGateway {
  Future<UserMarketPreferences> getCachedMarketPreferences();

  Future<UserMarketPreferences> getUserMarketPreferences();

  Future<void> saveUserMarketPreferences(UserMarketPreferences preferences);

  Future<void> syncCachedMarketPreferencesIfAuthenticated();
}

class SupabaseMarketPreferencesGateway implements MarketPreferencesGateway {
  SupabaseMarketPreferencesGateway(this._cache, this._connection);

  final CacheService _cache;
  final SupabaseConnection _connection;

  static const marketPreferencesCacheKey = 'settings.market_preferences';

  @override
  Future<UserMarketPreferences> getCachedMarketPreferences() async {
    final row = await _cache.getJsonMap(
      marketPreferencesCacheKey,
      debugLabel: 'market preferences',
    );
    if (row == null) return UserMarketPreferences.defaults;
    return UserMarketPreferences.fromJson(row);
  }

  @override
  Future<UserMarketPreferences> getUserMarketPreferences() async {
    final cached = await getCachedMarketPreferences();
    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) return cached;

    try {
      final row = await client
          .from('user_market_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return cached;
      final preferences = UserMarketPreferences.fromJson(
        Map<String, dynamic>.from(row),
      );
      await _cache.setJson(marketPreferencesCacheKey, preferences.toJson());
      return preferences;
    } catch (error) {
      AppLogger.d('Failed to load market preferences: $error');
      return cached;
    }
  }

  @override
  Future<void> saveUserMarketPreferences(
    UserMarketPreferences preferences,
  ) async {
    await _cache.setJson(marketPreferencesCacheKey, preferences.toJson());

    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) return;

    try {
      await client.from('user_market_preferences').upsert({
        'user_id': userId,
        ...preferences.toJson(),
      }, onConflict: 'user_id');
    } catch (error) {
      AppLogger.d('Failed to save market preferences: $error');
    }
  }

  @override
  Future<void> syncCachedMarketPreferencesIfAuthenticated() async {
    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) return;

    final cached = await getCachedMarketPreferences();
    if (!cached.hasCustomSelections) return;

    try {
      await client.from('user_market_preferences').upsert({
        'user_id': userId,
        ...cached.toJson(),
      }, onConflict: 'user_id');
    } catch (error) {
      AppLogger.d('Failed to sync cached market preferences: $error');
    }
  }
}
