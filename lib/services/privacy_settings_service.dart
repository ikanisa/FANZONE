import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/injection.dart';
import '../features/settings/data/preferences_gateway.dart';
import '../models/privacy_settings_model.dart';
import 'auth_service.dart';

class PrivacySettingsService {
  const PrivacySettingsService._();

  static Future<PrivacySettingsModel> getSettings() async {
    final userId = getIt<AuthService>().currentUser?.id;
    if (userId == null) return PrivacySettingsModel.defaults;
    return getIt<PreferencesGateway>().getPrivacySettings(userId);
  }

  static Future<void> saveSettings(PrivacySettingsModel settings) async {
    final userId = getIt<AuthService>().currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to update privacy settings.');
    }

    await getIt<PreferencesGateway>().savePrivacySettings(userId, settings);
  }
}
