import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/core/cache/cache_service.dart';
import 'package:fanzone/core/supabase/supabase_connection.dart';
import 'package:fanzone/features/auth/data/auth_gateway.dart';
import 'package:fanzone/features/home/data/competition_catalog_gateway.dart';
import 'package:fanzone/features/home/data/event_catalog_gateway.dart';
import 'package:fanzone/features/home/data/match_listing_gateway.dart';
import 'package:fanzone/features/home/data/team_catalog_gateway.dart';
import 'package:fanzone/features/predict/data/leaderboard_gateway.dart';
import 'package:fanzone/features/settings/data/account_settings_gateway.dart';
import 'package:fanzone/features/settings/data/notification_settings_gateway.dart';
import 'package:fanzone/features/wallet/data/wallet_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies that the Riverpod DI graph resolves all providers without errors.
/// This is a structural/wiring test — it ensures the provider dependency
/// graph is correctly connected after the GetIt → Riverpod migration.
void main() {
  late ProviderContainer container;

  setUp(() async {
    // Provide real SharedPreferences (in-memory for testing)
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Core providers resolve', () {
    test('cacheServiceProvider returns CacheService', () {
      final cache = container.read(cacheServiceProvider);
      expect(cache, isA<CacheService>());
    });

    test('supabaseConnectionProvider returns SupabaseConnection', () {
      final conn = container.read(supabaseConnectionProvider);
      expect(conn, isA<SupabaseConnection>());
    });
  });

  group('Auth providers resolve', () {
    test('authGatewayProvider returns AuthGateway', () {
      final gateway = container.read(authGatewayProvider);
      expect(gateway, isA<AuthGateway>());
    });
  });

  group('Home/Catalog providers resolve', () {
    test('competitionCatalogGatewayProvider', () {
      expect(
        container.read(competitionCatalogGatewayProvider),
        isA<CompetitionCatalogGateway>(),
      );
    });

    test('teamCatalogGatewayProvider', () {
      expect(
        container.read(teamCatalogGatewayProvider),
        isA<TeamCatalogGateway>(),
      );
    });

    test('eventCatalogGatewayProvider', () {
      expect(
        container.read(eventCatalogGatewayProvider),
        isA<EventCatalogGateway>(),
      );
    });

    test('matchListingGatewayProvider', () {
      expect(
        container.read(matchListingGatewayProvider),
        isA<MatchListingGateway>(),
      );
    });
  });

  group('Predict providers resolve', () {
    test('leaderboardGatewayProvider', () {
      expect(
        container.read(leaderboardGatewayProvider),
        isA<LeaderboardGateway>(),
      );
    });
  });

  group('Settings providers resolve', () {
    test('accountSettingsGatewayProvider', () {
      expect(
        container.read(accountSettingsGatewayProvider),
        isA<AccountSettingsGateway>(),
      );
    });

    test('notificationSettingsGatewayProvider', () {
      expect(
        container.read(notificationSettingsGatewayProvider),
        isA<NotificationSettingsGateway>(),
      );
    });
  });

  group('Wallet providers resolve', () {
    test('walletGatewayProvider', () {
      expect(container.read(walletGatewayProvider), isA<WalletGateway>());
    });
  });
}
