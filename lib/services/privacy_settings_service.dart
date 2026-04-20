import '../core/cache/shared_preferences_cache_service.dart';
import '../core/supabase/supabase_connection.dart';
import '../features/settings/data/account_settings_gateway.dart';
import '../models/privacy_settings_model.dart';

/// Static privacy settings service.
/// Uses Supabase directly for auth since it's called from non-Riverpod contexts.
class PrivacySettingsService {
  static final SupabaseConnection _connection = SupabaseConnectionImpl();

  static String? get _userId => _connection.currentUser?.id;

  static AccountSettingsGateway? _gateway;
  static AccountSettingsGateway get _accountSettings =>
      _gateway ??= SupabaseAccountSettingsGateway(
        SharedPreferencesCacheService.global,
        _connection,
      );

  static Future<PrivacySettingsModel> getSettings() async {
    final userId = _userId;
    if (userId == null) return const PrivacySettingsModel();
    return _accountSettings.getPrivacySettings(userId);
  }

  static Future<void> saveSettings(PrivacySettingsModel settings) async {
    final userId = _userId;
    if (userId == null) return;

    await _accountSettings.savePrivacySettings(userId, settings);
  }
}
