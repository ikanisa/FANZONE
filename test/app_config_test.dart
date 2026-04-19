import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('appName is FANZONE', () {
      expect(AppConfig.appName, 'FANZONE');
    });

    test('hasSupabaseConfig returns false without dart-defines', () {
      // Without --dart-define, both are empty strings
      expect(AppConfig.supabaseUrl, isEmpty);
      expect(AppConfig.supabaseAnonKey, isEmpty);
      expect(AppConfig.hasSupabaseConfig, false);
    });

    test('feature flags default to the launch product center', () {
      expect(AppConfig.enableWallet, true);
      expect(AppConfig.enablePredictions, true);
      expect(AppConfig.enableLeaderboard, true);
      expect(AppConfig.enableRewards, true);
      expect(AppConfig.enableMembership, false);
      expect(AppConfig.enableNotifications, false);
      expect(AppConfig.enableFanIdentity, true);
      expect(AppConfig.enableMarketplace, true);
    });
  });
}
