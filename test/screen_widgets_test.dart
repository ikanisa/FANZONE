import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/data/team_search_database.dart';
import 'package:fanzone/features/home/data/home_match_curator.dart';
import 'package:fanzone/features/home/screens/home_feed_screen.dart';
import 'package:fanzone/features/home/screens/home_matches_screen.dart';
import 'package:fanzone/features/home/screens/match_detail_screen.dart';
import 'package:fanzone/features/ordering/screens/venue_menu_screen.dart';
import 'package:fanzone/features/ordering/providers/venue_discovery_provider.dart';
import 'package:fanzone/features/games/data/games_repository.dart';
import 'package:fanzone/features/pools/data/pools_repository.dart'
    show matchPoolsProvider;
import 'package:fanzone/features/pools/screens/pools_screen.dart';
import 'package:fanzone/features/profile/screens/notifications_screen.dart';
import 'package:fanzone/features/profile/screens/profile_screen.dart';
import 'package:fanzone/features/settings/screens/privacy_settings_screen.dart';
import 'package:fanzone/features/settings/screens/settings_screen.dart';
import 'package:fanzone/features/settings/screens/support_info_screen.dart';
import 'package:fanzone/features/wallet/data/wallet_gateway.dart';
import 'package:fanzone/models/platform/notification_model.dart';
import 'package:fanzone/models/hospitality/venue_model.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/favorite_teams_provider.dart';
import 'package:fanzone/providers/home_feed_provider.dart';
import 'package:fanzone/providers/matches_provider.dart';
import 'package:fanzone/services/notification_service.dart';
import 'package:fanzone/services/wallet_service.dart';
import 'package:fanzone/theme/app_theme.dart';

import 'support/test_app.dart';
import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('screen widgets', () {
    testWidgets('bar screen guides users to choose a bar', (tester) async {
      await pumpAppScreen(tester, const VenueMenuScreen());
      await tester.pumpAndSettle();

      expect(find.text('Choose a bar'), findsOneWidget);
      expect(find.text('Bars'), findsOneWidget);
    });

    testWidgets('home matches screen renders live and upcoming match lists', (
      tester,
    ) async {
      final anchorDay = DateTime(2026, 6, 5);
      final filter = MatchesFilter(
        dateFrom: anchorDay.toIso8601String(),
        dateTo: anchorDay.add(const Duration(days: 14)).toIso8601String(),
        countryCode: 'MT',
        ascending: true,
        limit: 120,
      );

      await pumpAppScreen(
        tester,
        HomeMatchesScreen(anchorDay: anchorDay),
        overrides: [
          matchesProvider(filter).overrideWith(
            (ref) async => [
              sampleMatch(
                id: 'live_match',
                homeTeam: 'Live Club A',
                awayTeam: 'Live Club B',
                date: anchorDay,
                status: 'live',
                ftHome: 1,
                ftAway: 0,
              ),
              sampleMatch(
                id: 'upcoming_match',
                homeTeam: 'Future A',
                awayTeam: 'Future B',
                date: anchorDay.add(const Duration(days: 1)),
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Matches'), findsOneWidget);
      expect(find.text('1 live'), findsOneWidget);
      expect(find.text('1 upcoming'), findsOneWidget);
      expect(find.text('Live Club A'), findsOneWidget);
      expect(find.text('Future A'), findsOneWidget);

      await tester.tap(find.text('LIVE').first);
      await tester.pumpAndSettle();

      expect(find.text('Live Club A'), findsOneWidget);
      expect(find.text('Future A'), findsNothing);
    });

    testWidgets(
      'home hub renders bars teams pools matches and opens match list',
      (tester) async {
        await _pumpHomeRouter(tester);

        expect(find.text('MATCH DAY'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
        expect(find.text('1 live'), findsOneWidget);
        expect(find.text('1 upcoming'), findsOneWidget);
        expect(find.text('BARS'), findsOneWidget);
        expect(find.text('UAT Live Sports Bar'), findsOneWidget);
        expect(find.text('MY TEAMS'), findsOneWidget);
        expect(find.text('FLO'), findsOneWidget);
        expect(find.text('OPEN POOL'), findsOneWidget);
        expect(find.text('World Cup opener pool'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('home_match_world_cup_live')),
          260,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('LIVE & UPCOMING MATCHES'), findsOneWidget);
        expect(find.text('Mexico'), findsOneWidget);
        expect(find.text('South Africa'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home_matches_view_all')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('home_matches_view_all')));
        await tester.pumpAndSettle();

        expect(find.text('Matches'), findsOneWidget);
        expect(find.text('Live and upcoming fixtures'), findsOneWidget);
        expect(find.text('MATCH CENTER'), findsOneWidget);
      },
    );

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
          gamesProvider.overrideWith(
            (ref) async => [
              GameSessionSummary(
                id: 'game_1',
                venueId: 'venue_1',
                templateId: 'fan_trivia',
                templateName: 'Fan Trivia',
                templateCategory: 'trivia',
                status: 'live',
                scheduledStartAt: DateTime(2026, 6, 5, 18),
                rewardFet: 400,
                selectedQuestionCount: 20,
                venueName: 'Test Bar',
              ),
              GameSessionSummary(
                id: 'game_2',
                venueId: 'venue_1',
                templateId: 'song_guess',
                templateName: 'Song Guess',
                templateCategory: 'song_guess',
                status: 'lobby',
                scheduledStartAt: DateTime(2026, 6, 5, 19),
                rewardFet: 250,
                selectedQuestionCount: 12,
                venueName: 'Test Bar',
              ),
              GameSessionSummary(
                id: 'game_3',
                venueId: 'venue_1',
                templateId: 'music_bingo',
                templateName: 'Music Bingo',
                templateCategory: 'music_bingo',
                status: 'scheduled',
                scheduledStartAt: DateTime(2026, 6, 5, 20),
                rewardFet: 300,
                selectedQuestionCount: 0,
                venueName: 'Test Bar',
              ),
            ],
          ),
          myJoinedGameIdsProvider.overrideWith((ref) async => {'game_1'}),
          isFullyAuthenticatedProvider.overrideWith((ref) => true),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('Games'), findsAtLeastNWidgets(1));
      expect(find.text('Live games'), findsOneWidget);
      expect(find.text('Fan Trivia'), findsOneWidget);
      expect(find.text('JOINED'), findsOneWidget);
      expect(find.text('Song Guess'), findsOneWidget);
      expect(find.text('Music Bingo'), findsOneWidget);
      expect(find.text('Derby pool'), findsOneWidget);
      // FzPill renders camp labels uppercased
      expect(find.text('TEST CLUB A'), findsAtLeastNWidgets(1));
      expect(find.text('TEST CLUB B'), findsAtLeastNWidgets(1));
    });

    testWidgets('pools screen refresh reloads pools games and joined state', (
      tester,
    ) async {
      var poolLoads = 0;
      var gameLoads = 0;
      var joinedLoads = 0;

      await pumpAppScreen(
        tester,
        const PoolsScreen(),
        overrides: [
          poolsProvider.overrideWith((ref) async {
            poolLoads += 1;
            return const <PoolSummary>[];
          }),
          gamesProvider.overrideWith((ref) async {
            gameLoads += 1;
            return const <GameSessionSummary>[];
          }),
          myJoinedGameIdsProvider.overrideWith((ref) async {
            joinedLoads += 1;
            return const <String>{};
          }),
          isFullyAuthenticatedProvider.overrideWith((ref) => true),
        ],
      );
      await tester.pumpAndSettle();

      expect(poolLoads, 1);
      expect(gameLoads, 1);
      expect(joinedLoads, 1);

      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 420),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(poolLoads, 2);
      expect(gameLoads, 2);
      expect(joinedLoads, 2);
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
                title: 'Rewards adjustment',
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

      expect(find.text('REWARDS'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wallet-total-balance-value')),
        findsOneWidget,
      );
      expect(find.text('FET REWARDS'), findsOneWidget);
      expect(find.text('Send'), findsNothing);
      expect(find.textContaining('closed-loop rewards ledger'), findsOneWidget);
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

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('Fan ID 123456'), findsOneWidget);
      // ProfileDetailsCard section title is 'Profile'
      expect(find.text('Profile'), findsAtLeastNWidgets(1));
      expect(find.text('Country'), findsAtLeastNWidgets(1));
      expect(find.text('Favorite teams'), findsOneWidget);
      expect(find.text('Linked venues'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('PLAY'), findsNothing);
      expect(find.text('Match Pools'), findsNothing);
      expect(find.text('REWARDS'), findsNothing);
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
      expect(
        find.text('Verify WhatsApp to manage privacy controls.'),
        findsOneWidget,
      );
      expect(find.text('Allow Friends to Find Me'), findsNothing);
      expect(find.text('Verify WhatsApp'), findsOneWidget);
    });

    testWidgets('settings support info pages render in-app destinations', (
      tester,
    ) async {
      await pumpAppScreen(tester, const SupportInfoScreen.privacyPolicy());
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Account data'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('settings support rows navigate through in-app routes', (
      tester,
    ) async {
      await _pumpSettingsRouter(tester);

      await tester.tap(find.text('Help & FAQ'));
      await tester.pumpAndSettle();
      expect(find.text('Getting into FANZONE'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Account data'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();
      expect(find.text('Use of the app'), findsOneWidget);
      expect(find.text('Closed-loop rewards only'), findsOneWidget);
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

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
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
          matchPoolsProvider(match.id).overrideWith((ref) async => const []),
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
      expect(find.text('Create pool'), findsOneWidget);
      expect(find.text('Recent form'), findsNothing);
      expect(find.text('Standings snapshot'), findsNothing);
    });
  });
}

Future<void> _pumpSettingsRouter(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'help',
            builder: (context, state) => const SupportInfoScreen.help(),
          ),
          GoRoute(
            path: 'privacy-policy',
            builder: (context, state) =>
                const SupportInfoScreen.privacyPolicy(),
          ),
          GoRoute(
            path: 'terms',
            builder: (context, state) => const SupportInfoScreen.terms(),
          ),
        ],
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        bootstrapConfigProvider.overrideWithValue(
          _screenBootstrapConfig(showSettings: true),
        ),
        isFullyAuthenticatedProvider.overrideWith((ref) => false),
        notificationServiceProvider.overrideWith(
          _StaticNotificationService.new,
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: FzTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpHomeRouter(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final todayNow = DateTime.now();
  final today = DateTime(todayNow.year, todayNow.month, todayNow.day);
  final liveMatch = sampleMatch(
    id: 'world_cup_live',
    homeTeam: 'Mexico',
    awayTeam: 'South Africa',
    date: today,
    status: 'live',
    ftHome: 1,
    ftAway: 0,
  );
  final upcomingMatch = sampleMatch(
    id: 'world_cup_upcoming',
    homeTeam: 'Canada',
    awayTeam: 'Morocco',
    date: today.add(const Duration(days: 2)),
  );
  final homeFilter = MatchesFilter(
    dateFrom: today.toIso8601String(),
    dateTo: today.add(const Duration(days: 7)).toIso8601String(),
    countryCode: 'MT',
    ascending: true,
    limit: 24,
  );
  final matchesPageFilter = MatchesFilter(
    dateFrom: today.toIso8601String(),
    dateTo: today.add(const Duration(days: 14)).toIso8601String(),
    countryCode: 'MT',
    ascending: true,
    limit: 120,
  );
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeFeedScreen(),
        routes: [
          GoRoute(
            path: 'matches',
            builder: (context, state) => HomeMatchesScreen(anchorDay: today),
          ),
        ],
      ),
      GoRoute(
        path: '/venues',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Venues destination'))),
      ),
      GoRoute(
        path: '/pools',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Pools destination'))),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Rewards destination'))),
      ),
      GoRoute(
        path: '/match/:id',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Match detail'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        walletBalanceProvider.overrideWith(
          (ref) async => const WalletBalance(
            availableFet: 120,
            stakedFet: 0,
            pendingFet: 0,
            spentFet: 0,
            earnedFet: 120,
          ),
        ),
        activeVenuesProvider.overrideWith(
          (ref) async => const [
            VenueModel(
              id: 'venue_uat',
              name: 'UAT Live Sports Bar',
              countryCode: CountryCode.mt,
              venueType: VenueType.bar,
              currencyCode: 'EUR',
              city: 'Sliema',
              isOpen: true,
              onboardingStatus: OnboardingStatus.live,
            ),
          ],
        ),
        homeDefaultTeamsProvider.overrideWith(
          (ref) async => const [
            OnboardingTeam(
              id: 'floriana',
              name: 'Floriana FC',
              country: 'Malta',
              region: 'local',
              shortNameOverride: 'FLO',
              countryCodeOverride: 'MT',
            ),
          ],
        ),
        homeFeedMatchesProvider(homeFilter).overrideWith(
          (ref) async => HomeFeedSelection(
            liveMatches: [liveMatch],
            upcomingMatches: [upcomingMatch],
          ),
        ),
        matchesProvider(
          matchesPageFilter,
        ).overrideWith((ref) async => [liveMatch, upcomingMatch]),
        poolsProvider.overrideWith(
          (ref) async => const [
            PoolSummary(
              id: 'pool_world_cup',
              title: 'World Cup opener pool',
              status: 'open',
              scope: 'venue',
              isOfficial: true,
              totalMembers: 24,
              totalStakedFet: 240,
              entryFeeFet: 10,
              camps: [
                PoolCamp(
                  id: 'camp_home',
                  label: 'Mexico',
                  memberCount: 12,
                  totalStakedFet: 120,
                ),
                PoolCamp(
                  id: 'camp_away',
                  label: 'South Africa',
                  memberCount: 12,
                  totalStakedFet: 120,
                ),
              ],
            ),
          ],
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: FzTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _StaticNotificationService extends NotificationService {
  @override
  Future<NotificationPreferences> build() async {
    return const NotificationPreferences();
  }
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
