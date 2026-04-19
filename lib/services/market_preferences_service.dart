import '../core/di/injection.dart';
import '../features/settings/data/preferences_gateway.dart';
import '../models/user_market_preferences_model.dart';

class MarketPreferencesService {
  static PreferencesGateway get _gateway => getIt<PreferencesGateway>();

  static Future<UserMarketPreferences> getCachedPreferences() {
    return _gateway.getCachedMarketPreferences();
  }

  static Future<UserMarketPreferences> getUserPreferences() {
    return _gateway.getUserMarketPreferences();
  }

  static Future<void> saveUserPreferences(
    UserMarketPreferences preferences,
  ) {
    return _gateway.saveUserMarketPreferences(preferences);
  }

  static Future<void> syncCachedPreferencesIfAuthenticated() {
    return _gateway.syncCachedMarketPreferencesIfAuthenticated();
  }
}
