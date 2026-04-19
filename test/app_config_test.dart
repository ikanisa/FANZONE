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

    test('feature flags have safe defaults', () {
      // Wallet and predictions are OFF by default — require explicit opt-in
      expect(AppConfig.enableWallet, false);
      expect(AppConfig.enablePredictions, false);
      // Leaderboard is on by default (no backend dependency)
      expect(AppConfig.enableLeaderboard, true);
      // Rewards/membership/notifications are off by default
      expect(AppConfig.enableRewards, false);
      expect(AppConfig.enableMembership, false);
      expect(AppConfig.enableNotifications, false);
    });
  });
}
