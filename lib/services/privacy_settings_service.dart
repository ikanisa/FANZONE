import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabaseInitialized;
import '../models/privacy_settings_model.dart';

class PrivacySettingsService {
  const PrivacySettingsService._();

  static Future<PrivacySettingsModel> getSettings() async {
    if (!supabaseInitialized) return PrivacySettingsModel.defaults;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return PrivacySettingsModel.defaults;

    final data = await client
        .from('profiles')
        .select('show_name_on_leaderboards, allow_fan_discovery')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return PrivacySettingsModel.defaults;

    return PrivacySettingsModel(
      showNameOnLeaderboards:
          data['show_name_on_leaderboards'] as bool? ?? false,
      allowFanDiscovery: data['allow_fan_discovery'] as bool? ?? false,
    );
  }

  static Future<void> saveSettings(PrivacySettingsModel settings) async {
    if (!supabaseInitialized) {
      throw const AuthException(
        'Server not available. Please try again later.',
      );
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to update privacy settings.');
    }

    await client.from('profiles').upsert({
      'id': userId,
      'user_id': userId,
      'show_name_on_leaderboards': settings.showNameOnLeaderboards,
      'allow_fan_discovery': settings.allowFanDiscovery,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }
}
