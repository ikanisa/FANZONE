import 'market_preferences_gateway.dart';

export 'account_settings_gateway.dart';
export 'competition_preferences_gateway.dart';
export 'market_preferences_gateway.dart';
export 'notification_settings_gateway.dart';

/// Backwards-compatible alias retained until dependency injection codegen
/// is regenerated against the split settings gateways.
typedef PreferencesGateway = MarketPreferencesGateway;

class SupabasePreferencesGateway extends SupabaseMarketPreferencesGateway
    implements PreferencesGateway {
  SupabasePreferencesGateway(super.cache, super.connection);
}
