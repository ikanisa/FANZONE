import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/config/app_config.dart';
import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/config/runtime_bootstrap.dart';

void main() {
  setUp(() {
    runtimeBootstrapStore.update(BootstrapConfig.empty());
  });

  group('AppConfig', () {
    test('appName is FANZONE', () {
      expect(AppConfig.appName, 'FANZONE');
    });

    test('default appVersion matches the current release line', () {
      expect(AppConfig.appVersion, '1.1.0');
    });

    test('hasSupabaseConfig returns false without dart-defines', () {
      // Without --dart-define, both are empty strings
      expect(AppConfig.supabaseUrl, isEmpty);
      expect(AppConfig.supabaseAnonKey, isEmpty);
      expect(AppConfig.hasSupabaseConfig, false);
    });

    test('feature flags are disabled until bootstrap config is loaded', () {
      expect(AppConfig.enableWallet, false);
      expect(AppConfig.enablePredictions, false);
      expect(AppConfig.enableLeaderboard, false);
      expect(AppConfig.enableRewards, false);
      expect(AppConfig.enableNotifications, false);
    });

    test('runtime bootstrap flags drive feature availability', () {
      runtimeBootstrapStore.update(
        BootstrapConfig(
          regions: const {},
          phonePresets: const {},
          currencyDisplay: const {},
          countryCurrencies: const {},
          featureFlags: const {
            'predictions': true,
            'wallet': true,
            'leaderboard': false,
            'rewards': true,
            'notifications': true,
          },
          appConfig: const {},
          launchMoments: const [],
        ),
      );

      expect(AppConfig.enablePredictions, true);
      expect(AppConfig.enableWallet, true);
      expect(AppConfig.enableLeaderboard, false);
      expect(AppConfig.enableRewards, true);
      expect(AppConfig.enableNotifications, true);
    });
  });
}
