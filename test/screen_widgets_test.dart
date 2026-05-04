import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/features/home/screens/match_detail_screen.dart';
import 'package:fanzone/features/ordering/screens/venue_menu_screen.dart';
import 'package:fanzone/features/pools/screens/pools_screen.dart';
import 'package:fanzone/features/profile/screens/notifications_screen.dart';
import 'package:fanzone/features/profile/screens/profile_screen.dart';
import 'package:fanzone/features/settings/screens/privacy_settings_screen.dart';
import 'package:fanzone/models/platform/notification_model.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/favorite_teams_provider.dart';
import 'package:fanzone/providers/matches_provider.dart';
import 'package:fanzone/services/notification_service.dart';
import 'package:fanzone/services/wallet_service.dart';

import 'support/test_app.dart';
import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('screen widgets', () {
    testWidgets('bar screen guides guests to scan a table QR', (tester) async {
      await pumpAppScreen(tester, const VenueMenuScreen());
      await tester.pumpAndSettle();

      expect(find.text('Scan a table QR'), findsOneWidget);
      expect(find.text('Bars'), findsOneWidget);
    });

    testWidgets('pools screen renders open pools and camps', (tester) async {
      const pool = PoolSummary(
        id: 'pool_1',
        title: 'Derby pool',
        status: 'open',
        scope: 'venue',
        isOfficial: true,
        totalMembers: 19,
        totalStakedFet: 190,
        entryFeeFet: 10,
        camps: [
          PoolCamp(
            id: 'camp_home',
            label: 'Test Club A',
            memberCount: 11,
            totalStakedFet: 110,
          ),
          PoolCamp(
            id: 'camp_draw',
            label: 'Draw',
            memberCount: 3,
            totalStakedFet: 30,
          ),
          PoolCamp(
            id: 'camp_away',
            label: 'Test Club B',
            memberCount: 5,
            totalStakedFet: 50,
          ),
        ],
      );

      await pumpAppScreen(
        tester,
        const PoolsScreen(),
        overrides: [
          poolsProvider.overrideWith((ref) async => const [pool]),
          isFullyAuthenticatedProvider.overrideWith((ref) => true),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('Derby pool'), findsOneWidget);
      // FzPill renders camp labels uppercased
      expect(find.text('TEST CLUB A'), findsAtLeastNWidgets(1));
      expect(find.text('TEST CLUB B'), findsAtLeastNWidgets(1));
    });

    testWidgets('wallet screen renders balance and history', (tester) async {
      await pumpAppScreen(
        tester,
        const WalletScreen(),
        overrides: [
          walletServiceProvider.overrideWith(() => FakeWalletService(420)),
          transactionServiceProvider.overrideWith(
            () => FakeTransactionService([
              sampleWalletTransaction(),
              sampleWalletTransaction(
                id: 'tx_2',
                title: 'Wallet transfer',
                amount: 120,
                type: 'spend',
                dateStr: '1d ago',
              ),
            ]),
          ),
          isAuthenticatedProvider.overrideWith((ref) => true),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('WALLET'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wallet-total-balance-value')),
        findsOneWidget,
      );
      expect(find.text('FET BALANCE'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Pool reward'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Pool reward'), findsOneWidget);
    });

    testWidgets('profile screen renders account sections for signed-in users', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const ProfileScreen(),
        overrides: [
          walletServiceProvider.overrideWith(() => FakeWalletService(980)),
          isAuthenticatedProvider.overrideWith((ref) => true),
          currentUserProvider.overrideWith((ref) => null),
          userFanIdProvider.overrideWith((ref) async => '123456'),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
          favoriteTeamRecordsProvider.overrideWith((ref) async => const []),
          bootstrapConfigProvider.overrideWithValue(
            _screenBootstrapConfig(
              showPools: true,
              showWallet: true,
              showNotifications: true,
              showSettings: true,
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Fan ID 123456'), findsOneWidget);
      // ProfileDetailsCard section title is 'Profile'
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Country'), findsAtLeastNWidgets(1));
      expect(find.text('Favorite teams'), findsOneWidget);
      expect(find.text('Linked venues'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('PLAY'), findsNothing);
      expect(find.text('Match Pools'), findsNothing);
      expect(find.text('WALLET'), findsNothing);
      expect(find.text('Select Identity'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-identity-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Select Identity'), findsNothing);
      // Account links rendered via ProfileAccountLinksCard
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('privacy settings screen matches the source sections', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const PrivacySettingsScreen(),
        overrides: [isAuthenticatedProvider.overrideWith((ref) => false)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Phone Number Hidden'), findsOneWidget);
      expect(find.text('Anonymous Rewards'), findsOneWidget);
      expect(find.text('Display Name in Pool Activity'), findsOneWidget);
      expect(find.text('Allow Friends to Find Me'), findsNothing);
      const verificationCopy =
          '* Verification required to change visibility settings.';
      await tester.scrollUntilVisible(
        find.text(verificationCopy),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(verificationCopy), findsOneWidget);
    });

    testWidgets('notifications screen keeps the canonical alerts language', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const NotificationsScreen(),
        overrides: [
          notificationLogProvider.overrideWith(
            (ref) async => [
              NotificationItem(
                id: 'notif_1',
                type: 'pool_settled',
                title: 'Pool settled',
                body: 'Your derby pool has been settled.',
                sentAt: DateTime(2026, 4, 19, 12),
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Pool settled'), findsOneWidget);
    });

    testWidgets('match detail screen renders the pool-first match center', (
      tester,
    ) async {
      final match = sampleMatch(
        id: 'detail_match',
        status: 'live',
        ftHome: 2,
        ftAway: 1,
      );

      await pumpAppScreen(
        tester,
        MatchDetailScreen(matchId: match.id),
        surfaceSize: const Size(390, 2000), // Massive height to avoid scrolling
        overrides: [
          matchDetailProvider(
            match.id,
          ).overrideWith((ref) => Stream.value(match)),
        ],
      );
      // Use explicit pump() instead of pumpAndSettle() because stream-based
      // providers (matchDetailProvider, competitionMatchesProvider) leave a
      // polling timer that triggers 'Timer still pending' assertions.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Club A'), findsAtLeastNWidgets(1));
      expect(find.text('Test Club B'), findsAtLeastNWidgets(1));
      expect(find.text('Match Pools'), findsAtLeastNWidgets(1));
      expect(find.text('Open match pools'), findsOneWidget);
      expect(find.text('Recent form'), findsNothing);
      expect(find.text('Standings snapshot'), findsNothing);
    });
  });
}

PlatformFeatureInfo _screenFeature(
  String featureKey, {
  required String displayName,
  required String routeKey,
  bool authRequired = false,
  bool showInNavigation = false,
  bool showOnHome = false,
  int sortOrder = 100,
}) {
  return PlatformFeatureInfo.fromJson({
    'feature_key': featureKey,
    'display_name': displayName,
    'status': 'active',
    'is_enabled': true,
    'default_route_key': routeKey,
    'auth_required': authRequired,
    'channels': {
      'mobile': {
        'channel': 'mobile',
        'is_visible': true,
        'is_enabled': true,
        'show_in_navigation': showInNavigation,
        'show_on_home': showOnHome,
        'sort_order': sortOrder,
        'route_key': routeKey,
        'navigation_label': displayName,
      },
      'web': {
        'channel': 'web',
        'is_visible': true,
        'is_enabled': true,
        'show_in_navigation': showInNavigation,
        'show_on_home': showOnHome,
        'sort_order': sortOrder,
        'route_key': routeKey,
        'navigation_label': displayName,
      },
    },
    'resolved_state': {
      'is_operational': true,
      'is_visible': true,
      'is_available': true,
      'show_in_navigation': showInNavigation,
      'show_on_home': showOnHome,
      'route_key': routeKey,
      'sort_order': sortOrder,
    },
  });
}

PlatformContentBlockInfo _screenHomeBlock(
  String blockKey, {
  required String blockType,
  required String title,
  required String featureKey,
  required int sortOrder,
  Map<String, dynamic> content = const {},
}) {
  return PlatformContentBlockInfo.fromJson({
    'block_key': blockKey,
    'block_type': blockType,
    'title': title,
    'content': content,
    'target_channel': 'mobile',
    'is_active': true,
    'sort_order': sortOrder,
    'feature_key': featureKey,
    'placement_key': 'home.primary',
  });
}

BootstrapConfig _screenBootstrapConfig({
  bool showFixtures = false,
  bool showPools = false,
  bool showWallet = false,
  bool showNotifications = false,
  bool showSettings = false,
  bool includeHomeBlocks = false,
}) {
  final features = <PlatformFeatureInfo>[
    if (showFixtures)
      _screenFeature(
        'fixtures',
        displayName: 'Fixtures',
        routeKey: '/pools',
        showInNavigation: true,
        showOnHome: true,
        sortOrder: 20,
      ),
    if (showPools)
      _screenFeature(
        'pools',
        displayName: 'Pools',
        routeKey: '/pools',
        authRequired: true,
        showInNavigation: true,
        showOnHome: true,
        sortOrder: 30,
      ),
    if (showWallet)
      _screenFeature(
        'wallet',
        displayName: 'Wallet',
        routeKey: '/wallet',
        authRequired: true,
        sortOrder: 50,
      ),
    if (showNotifications)
      _screenFeature(
        'notifications',
        displayName: 'Notifications',
        routeKey: '/notifications',
        authRequired: true,
        sortOrder: 60,
      ),
    if (showSettings)
      _screenFeature(
        'settings',
        displayName: 'Settings',
        routeKey: '/settings',
        sortOrder: 70,
      ),
  ];

  final blocks = <PlatformContentBlockInfo>[
    if (includeHomeBlocks)
      _screenHomeBlock(
        'home_live_matches',
        blockType: 'live_matches',
        title: 'Live Matches',
        featureKey: 'pools',
        sortOrder: 20,
      ),
    if (includeHomeBlocks)
      _screenHomeBlock(
        'home_upcoming_matches',
        blockType: 'upcoming_matches',
        title: 'Upcoming Matches',
        featureKey: 'pools',
        sortOrder: 30,
      ),
  ];

  return BootstrapConfig(
    platformConfigVersion: 'cfg-screen-tests',
    regions: const {},
    phonePresets: const {},
    currencyDisplay: const {},
    countryCurrencies: const {},
    featureFlags: const {},
    appConfig: const {},
    launchMoments: const [],
    platformFeatures: features,
    platformContentBlocks: blocks,
  );
}
