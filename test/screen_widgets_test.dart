import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/data/team_search_database.dart';
import 'package:fanzone/features/fixtures/screens/fixtures_screen.dart';
import 'package:fanzone/features/home/screens/home_feed_screen.dart';
import 'package:fanzone/features/home/screens/match_detail_screen.dart';
import 'package:fanzone/features/identity/screens/fan_id_screen.dart';
import 'package:fanzone/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:fanzone/features/predict/screens/predict_screen.dart';
import 'package:fanzone/features/profile/providers/profile_identity_provider.dart';
import 'package:fanzone/features/profile/screens/notifications_screen.dart';
import 'package:fanzone/features/profile/screens/profile_screen.dart';
import 'package:fanzone/features/settings/screens/privacy_settings_screen.dart';
import 'package:fanzone/features/social/screens/social_hub_screen.dart';
import 'package:fanzone/features/teams/screens/team_profile_canonical_screen.dart';
import 'package:fanzone/models/featured_event_model.dart';
import 'package:fanzone/models/match_advanced_stats_model.dart';
import 'package:fanzone/models/match_odds_model.dart';
import 'package:fanzone/models/notification_model.dart';
import 'package:fanzone/models/pool.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/models/match_model.dart';
import 'package:fanzone/models/match_player_stats_model.dart';
import 'package:fanzone/models/team_contribution_model.dart';
import 'package:fanzone/models/team_model.dart';
import 'package:fanzone/models/team_supporter_model.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/competitions_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/favorite_teams_provider.dart';
import 'package:fanzone/providers/favourites_provider.dart';
import 'package:fanzone/providers/featured_events_provider.dart';
import 'package:fanzone/providers/match_detail_providers.dart';
import 'package:fanzone/providers/market_preferences_provider.dart';
import 'package:fanzone/providers/matches_provider.dart';
import 'package:fanzone/providers/standings_provider.dart';
import 'package:fanzone/providers/teams_provider.dart';
import 'package:fanzone/services/leaderboard_service.dart';
import 'package:fanzone/services/notification_service.dart';
import 'package:fanzone/services/pool_service.dart';
import 'package:fanzone/services/team_community_service.dart';
import 'package:fanzone/services/wallet_service.dart';
import 'package:fanzone/theme/app_theme.dart';

import 'support/test_app.dart';
import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('screen widgets', () {
    testWidgets(
      'home feed stays aligned to the canonical prediction-first layout',
      (tester) async {
        final today = DateTime.now();
        final selectedDate = DateTime(today.year, today.month, today.day);
        final feedFilter = MatchesFilter(
          dateFrom: selectedDate.toIso8601String(),
          dateTo: selectedDate.add(const Duration(days: 7)).toIso8601String(),
          limit: 200,
          ascending: true,
        );
        final liveMatch = sampleMatch(
          id: 'home_live',
          date: selectedDate,
          status: 'live',
          ftHome: 1,
          ftAway: 0,
        );
        final upcomingMatch = sampleMatch(
          id: 'home_upcoming',
          date: selectedDate,
          homeTeam: 'Barcelona',
          awayTeam: 'Real Madrid',
        );

        await pumpAppScreen(
          tester,
          const HomeFeedScreen(),
          overrides: [
            matchesProvider(
              feedFilter,
            ).overrideWith((ref) async => [liveMatch, upcomingMatch]),
            supportedTeamsServiceProvider.overrideWith(
              () => _StaticSupportedTeamsController(const <String>{}),
            ),
            teamNewsProvider(
              'liverpool',
              limit: 1,
            ).overrideWith((ref) async => const []),
            profileIdentityProvider.overrideWith(
              () => _StaticProfileIdentityController(null),
            ),
          ],
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('Predictions'), findsNothing);
        expect(find.text('Live Action'), findsOneWidget);
        expect(find.text('Upcoming'), findsOneWidget);
        expect(find.byTooltip('Create pool'), findsNothing);
        expect(
          find.byKey(const ValueKey('home-match-card-home_live')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-match-card-home_upcoming')),
          findsOneWidget,
        );
        expect(find.text('PREDICT'), findsNWidgets(2));
        expect(find.text('POOL'), findsNWidgets(2));
        expect(find.text('FREE ENTRY'), findsNothing);
        expect(find.text('MATCHDAY HUB'), findsNothing);
      },
    );

    testWidgets(
      'leaderboard keeps the canonical 4-tab layout with podium and fan clubs view',
      (tester) async {
        final entries = <Map<String, dynamic>>[
          {'rank': 1, 'name': 'SpartanKing', 'fet': 15200},
          {'rank': 2, 'name': 'MaltaFan', 'fet': 12400},
          {'rank': 3, 'name': 'PacevillePro', 'fet': 10100},
          {'rank': 4, 'name': 'User_4', 'fet': 6500},
          {'rank': 5, 'name': 'User_5', 'fet': 5500},
        ];

        await pumpAppScreen(
          tester,
          const LeaderboardScreen(),
          overrides: [
            globalLeaderboardProvider.overrideWith(
              () => _StaticGlobalLeaderboard(entries),
            ),
            userRankProvider.overrideWith((ref) async => 42),
            walletServiceProvider.overrideWith(() => FakeWalletService(2100)),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.text('Global'), findsOneWidget);
        expect(find.text('Weekly'), findsOneWidget);
        expect(find.text('Friends'), findsOneWidget);
        expect(find.text('Fan Clubs'), findsOneWidget);
        expect(find.byIcon(LucideIcons.trophy), findsNWidgets(3));
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Accuracy 68%'), findsOneWidget);
        expect(find.text('SpartanKing'), findsOneWidget);

        await tester.tap(find.text('Fan Clubs'));
        await tester.pumpAndSettle();

        expect(find.text('Hamrun S.'), findsOneWidget);
        expect(find.text('Floriana'), findsOneWidget);
        expect(find.byIcon(LucideIcons.trendingUp), findsWidgets);
        expect(find.text('Accuracy 68%'), findsNothing);
      },
    );

    testWidgets('predict screen renders pools and tabs', (tester) async {
      await pumpAppScreen(
        tester,
        const PredictScreen(),
        overrides: [
          poolServiceProvider.overrideWith(
            () => FakePoolService([samplePool()]),
          ),
          myEntriesProvider.overrideWith(() => FakeMyEntries([])),
          currentUserProvider.overrideWith((ref) => null),
          isAuthenticatedProvider.overrideWith((ref) => false),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('FEATURED'), findsOneWidget);
      expect(find.text('OPEN'), findsAtLeastNWidgets(1));
      expect(find.text('Liverpool'), findsAtLeastNWidgets(1));
      expect(find.text('Arsenal'), findsAtLeastNWidgets(1));
      expect(find.text('JOIN'), findsOneWidget);
      expect(find.byTooltip('Create pool'), findsWidgets);
    });

    testWidgets('create pool screen renders the live route entry state', (
      tester,
    ) async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 14));
      final createPoolFilter = MatchesFilter(
        dateFrom:
            '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
        dateTo:
            '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
        limit: 24,
        ascending: true,
      );
      final poolMatch = sampleMatch(
        homeTeam: 'Girona FC',
        awayTeam: 'Real Betis Balompié',
        date: start,
        kickoffTime: '21:30',
      );

      await pumpAppScreen(
        tester,
        const CreatePoolScreen(),
        overrides: [
          poolServiceProvider.overrideWith(
            () => FakePoolService([samplePool()]),
          ),
          matchesProvider(
            createPoolFilter,
          ).overrideWith((ref) async => [poolMatch]),
          myEntriesProvider.overrideWith(() => FakeMyEntries([])),
          currentUserProvider.overrideWith((ref) => null),
          isAuthenticatedProvider.overrideWith((ref) => false),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Create'), findsOneWidget);
      expect(find.text('New Pool'), findsOneWidget);
      expect(find.text('Select a Match'), findsOneWidget);
      expect(find.text('Girona FC vs Real Betis Balompié'), findsOneWidget);
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
                title: 'Reward redeemed',
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

      expect(find.text('Wallet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wallet-total-balance-value')),
        findsOneWidget,
      );
      expect(find.text('Total Balance'), findsOneWidget);
      expect(find.text('SEND'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Challenge payout'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Challenge payout'), findsOneWidget);
    });

    testWidgets('profile screen renders account sections for signed-in users', (
      tester,
    ) async {
      const selectedTeam = FavoriteTeamRecordDto(
        teamId: 'liverpool',
        teamName: 'Liverpool',
        teamShortName: 'LIV',
        source: 'local',
      );

      await pumpAppScreen(
        tester,
        const ProfileScreen(),
        overrides: [
          walletServiceProvider.overrideWith(() => FakeWalletService(980)),
          isAuthenticatedProvider.overrideWith((ref) => true),
          currentUserProvider.overrideWith((ref) => null),
          userFanIdProvider.overrideWith((ref) async => '123456'),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
          favoriteTeamRecordsProvider.overrideWith(
            (ref) async => [selectedTeam],
          ),
          profileIdentityProvider.overrideWith(
            () => _StaticProfileIdentityController(selectedTeam),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Fan ID 123456'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Clubs'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Select Identity'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-identity-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Select Identity'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Memberships'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Memberships'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
    });

    testWidgets('fan id screen follows the canonical identity layout', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const FanIdScreen(),
        overrides: [userFanIdProvider.overrideWith((ref) async => '123456')],
      );
      await tester.pumpAndSettle();

      expect(find.text('My Fan ID'), findsOneWidget);
      expect(find.text('FAN ID SPECIFICATION'), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
      expect(find.text('Auto-assigned on first app open'), findsOneWidget);
      expect(find.text('IDENTITY RULES'), findsOneWidget);
      expect(find.text('Anonymous'), findsOneWidget);
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
      expect(find.text('Anonymous Contributions'), findsOneWidget);
      expect(find.text('Display Name on Leaderboards'), findsOneWidget);
      expect(find.text('Allow Friends to Find Me'), findsOneWidget);
      expect(
        find.text('* Verification required to change visibility settings.'),
        findsOneWidget,
      );
    });

    testWidgets('social hub screen keeps the original tabs and fan-zone hero', (
      tester,
    ) async {
      const team = TeamModel(
        id: 'hamrun',
        name: 'Hamrun Spartans',
        shortName: 'Hamrun',
        country: 'Malta',
        fanCount: 1240,
      );

      await pumpAppScreen(
        tester,
        const SocialHubScreen(),
        overrides: [
          poolServiceProvider.overrideWith(
            () => FakePoolService([
              samplePool(),
              ScorePool(
                id: 'pool_2',
                matchId: 'match_1',
                matchName: 'Hamrun Spartans vs Valletta FC',
                creatorId: 'creator_2',
                creatorName: 'GozitanFan',
                creatorPrediction: 'Hamrun Spartans 1 - 0 Valletta FC',
                stake: 100,
                totalPool: 900,
                participantsCount: 10,
                status: 'open',
                lockAt: DateTime(2026, 4, 19, 20),
              ),
            ]),
          ),
          teamsProvider.overrideWith((ref) async => const [team]),
          supportedTeamsServiceProvider.overrideWith(
            () => _StaticSupportedTeamsController(const {'hamrun'}),
          ),
          userFanIdProvider.overrideWith((ref) async => '123456'),
          teamAnonymousFansProvider(team.id).overrideWith(
            (ref) async => [
              AnonymousFanRecord(
                anonymousFanId: 'Hamrun_Ultra',
                joinedAt: DateTime(2026, 4, 1),
              ),
              AnonymousFanRecord(
                anonymousFanId: '123456',
                joinedAt: DateTime(2026, 4, 2),
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Social Hub'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Club Fan Zone'), findsOneWidget);
      await tester.tap(find.text('Club Fan Zone'));
      await tester.pumpAndSettle();
      expect(find.text('HAMRUN FANS'), findsOneWidget);
      expect(find.text('FAN LEADERBOARD'), findsOneWidget);
    });

    testWidgets('team profile screen restores the original tab contract', (
      tester,
    ) async {
      const team = TeamModel(
        id: 'hamrun',
        name: 'Hamrun Spartans',
        shortName: 'Hamrun',
        country: 'Malta',
        leagueName: 'Malta Premier League',
        competitionIds: ['mpl'],
        fanCount: 1240,
        fetContributionsEnabled: true,
      );
      final match = sampleMatch(
        id: 'hamrun_match',
        competitionId: 'mpl',
        homeTeam: 'Hamrun Spartans',
        awayTeam: 'Valletta FC',
        status: 'finished',
        ftHome: 2,
        ftAway: 0,
      );

      await pumpAppScreen(
        tester,
        const TeamProfileScreen(teamId: 'hamrun'),
        overrides: [
          teamProvider(team.id).overrideWith((ref) async => team),
          teamsProvider.overrideWith((ref) async => const [team]),
          competitionsProvider.overrideWith(
            (ref) async => [
              sampleCompetition(
                id: 'mpl',
                name: 'Malta Premier League',
                shortName: 'MPL',
                country: 'Malta',
              ),
            ],
          ),
          teamMatchesProvider(
            team.id,
          ).overrideWith((ref) => Stream.value([match])),
          teamCommunityStatsProvider(team.id).overrideWith(
            (ref) async => const TeamCommunityStats(
              teamId: 'hamrun',
              teamName: 'Hamrun Spartans',
              fanCount: 1240,
              totalFetContributed: 48200,
              contributionCount: 84,
              supportersLast30d: 42,
            ),
          ),
          teamAnonymousFansProvider(team.id).overrideWith(
            (ref) async => [
              AnonymousFanRecord(
                anonymousFanId: '102948',
                joinedAt: DateTime(2026, 4, 1),
              ),
              AnonymousFanRecord(
                anonymousFanId: '483291',
                joinedAt: DateTime(2026, 4, 2),
              ),
            ],
          ),
          supportedTeamsServiceProvider.overrideWith(
            () => _StaticSupportedTeamsController(const {'hamrun'}),
          ),
          isAuthenticatedProvider.overrideWith((ref) => true),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Team Profile'), findsOneWidget);
      expect(find.text('Hamrun Spartans'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Fixtures'), findsOneWidget);
      expect(find.text('Contribute'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('LATEST MATCH'), findsOneWidget);
    });

    testWidgets('social hub shows a visible error state when teams fail', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const SocialHubScreen(),
        overrides: [
          teamsProvider.overrideWith((ref) async => throw StateError('boom')),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load social hub'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('team profile keeps the shell visible on load failure', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const TeamProfileScreen(teamId: 'missing'),
        overrides: [
          teamProvider(
            'missing',
          ).overrideWith((ref) async => throw StateError('boom')),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Team Profile'), findsOneWidget);
      expect(find.text('Could not load team profile'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('notifications screen keeps the canonical inbox language', (
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
                body: 'Your derby pool has been graded.',
                sentAt: DateTime(2026, 4, 19, 12),
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Pool settled'), findsOneWidget);
    });

    testWidgets('match detail screen renders scoreboard and tabs', (
      tester,
    ) async {
      final match = sampleMatch(
        id: 'detail_match',
        status: 'live',
        ftHome: 2,
        ftAway: 1,
      );
      final competition = sampleCompetition();

      await pumpAppScreen(
        tester,
        MatchDetailScreen(matchId: match.id),
        overrides: [
          matchDetailProvider(
            match.id,
          ).overrideWith((ref) => Stream.value(match)),
          competitionProvider(
            competition.id,
          ).overrideWith((ref) async => competition),
          competitionMatchesProvider(
            competition.id,
          ).overrideWith((ref) => Stream.value(<MatchModel>[])),
          competitionStandingsProvider(
            CompetitionStandingsFilter(
              competitionId: competition.id,
              season: match.season,
            ),
          ).overrideWith((ref) async => []),
          matchAdvancedStatsProvider(match.id).overrideWith(
            (ref) => Stream.value(
              MatchAdvancedStats(id: 'stats_1', matchId: match.id),
            ),
          ),
          matchPlayerStatsProvider(
            match.id,
          ).overrideWith((ref) => Stream.value(<MatchPlayerStats>[])),
          matchOddsProvider(match.id).overrideWith(
            (ref) => Stream.value(
              MatchOddsModel(
                matchId: match.id,
                homeMultiplier: 1.9,
                drawMultiplier: 3.1,
                awayMultiplier: 2.2,
                provider: 'test',
              ),
            ),
          ),
          matchAiAnalysisProvider(match.id).overrideWith((ref) async => null),
          matchAlertEnabledProvider(
            match.id,
          ).overrideWith((ref) async => false),
          favouritesProvider.overrideWith(
            () => _StaticFavouritesNotifier(const FavouritesState()),
          ),
        ],
      );
      // Use explicit pump() instead of pumpAndSettle() because stream-based
      // providers (matchDetailProvider, competitionMatchesProvider) leave a
      // polling timer that triggers 'Timer still pending' assertions.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Liverpool'), findsAtLeastNWidgets(1));
      expect(find.text('Arsenal'), findsAtLeastNWidgets(1));
      expect(find.text('Predict'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.byTooltip('Share match'), findsOneWidget);
    });

    testWidgets(
      'fixtures screen defaults to matches and can switch to competitions',
      (tester) async {
        final today = DateTime.now();
        final selectedDate = DateTime(today.year, today.month, today.day);
        final majorEvent = FeaturedEventModel(
          id: 'ucl_2026',
          name: 'Champions League',
          shortName: 'UCL',
          eventTag: 'ucl-final-2026',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 6, 1),
        );
        final premierLeague = sampleCompetition(country: 'England');
        final maltaLeague = sampleCompetition(
          id: 'mpl',
          name: 'Maltese Premier League',
          shortName: 'MPL',
          country: 'Malta',
        );

        await pumpAppScreen(
          tester,
          const FixturesScreen(),
          overrides: [
            primaryMarketRegionProvider.overrideWith((ref) => 'europe'),
            competitionsProvider.overrideWith(
              (ref) async => [premierLeague, maltaLeague],
            ),
            top5EuropeanLeaguesProvider.overrideWith(
              (ref) async => [premierLeague],
            ),
            majorCompetitionsProvider.overrideWith((ref) async => [majorEvent]),
            localLeaguesProvider(
              'europe',
            ).overrideWith((ref) async => [maltaLeague]),
            favoriteTeamRecordsProvider.overrideWith((ref) async => const []),
            teamsProvider.overrideWith((ref) async => const []),
            matchesByDateProvider(selectedDate).overrideWith(
              (ref) => Stream.value([sampleMatch(date: selectedDate)]),
            ),
            favouritesProvider.overrideWith(
              () => _StaticFavouritesNotifier(const FavouritesState()),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.text('Fixtures'), findsOneWidget);
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.byTooltip('Search fixtures'), findsOneWidget);

        await tester.tap(find.byTooltip('Competitions'));
        await tester.pumpAndSettle();

        expect(find.text('Europe'), findsOneWidget);
        expect(find.text('For You'), findsOneWidget);
      },
    );

    testWidgets(
      'fixtures open pools action switches to the pools shell branch',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final today = DateTime.now();
        final selectedDate = DateTime(today.year, today.month, today.day);
        final sampleLeague = sampleCompetition(
          id: 'la_liga',
          name: 'La Liga',
          shortName: 'LL',
          country: 'Spain',
        );

        final router = GoRouter(
          initialLocation: '/fixtures',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) =>
                  Scaffold(body: navigationShell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (context, state) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/fixtures',
                      builder: (context, state) => const FixturesScreen(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/pools',
                      builder: (context, state) => const Scaffold(
                        body: Center(child: Text('Pools destination')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              competitionsProvider.overrideWith((ref) async => [sampleLeague]),
              top5EuropeanLeaguesProvider.overrideWith(
                (ref) async => [sampleLeague],
              ),
              localLeaguesProvider(
                'malta',
              ).overrideWith((ref) async => const []),
              favoriteTeamRecordsProvider.overrideWith((ref) async => const []),
              teamsProvider.overrideWith((ref) async => const []),
              matchesByDateProvider(selectedDate).overrideWith(
                (ref) => Stream.value([
                  sampleMatch(
                    id: 'fixture_match',
                    date: selectedDate,
                    competitionId: 'la_liga',
                    homeTeam: 'Girona FC',
                    awayTeam: 'Real Betis Balompié',
                  ),
                ]),
              ),
              favouritesProvider.overrideWith(
                () => _StaticFavouritesNotifier(const FavouritesState()),
              ),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: FzTheme.dark(),
              darkTheme: FzTheme.dark(),
              themeMode: ThemeMode.dark,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Fixtures'), findsOneWidget);

        await tester.tap(find.byTooltip('Open pools').first);
        await tester.pumpAndSettle();

        expect(find.text('Pools destination'), findsOneWidget);
      },
    );

    testWidgets('fixture action buttons expose tappable semantics', (
      tester,
    ) async {
      final today = DateTime.now();
      final selectedDate = DateTime(today.year, today.month, today.day);
      final sampleLeague = sampleCompetition(
        id: 'la_liga',
        name: 'La Liga',
        shortName: 'LL',
        country: 'Spain',
      );

      await pumpAppScreen(
        tester,
        const FixturesScreen(),
        overrides: [
          competitionsProvider.overrideWith((ref) async => [sampleLeague]),
          top5EuropeanLeaguesProvider.overrideWith(
            (ref) async => [sampleLeague],
          ),
          localLeaguesProvider('malta').overrideWith((ref) async => const []),
          favoriteTeamRecordsProvider.overrideWith((ref) async => const []),
          teamsProvider.overrideWith((ref) async => const []),
          matchesByDateProvider(selectedDate).overrideWith(
            (ref) => Stream.value([
              sampleMatch(
                id: 'fixture_match',
                date: selectedDate,
                competitionId: 'la_liga',
                homeTeam: 'Girona FC',
                awayTeam: 'Real Betis Balompié',
              ),
            ]),
          ),
          favouritesProvider.overrideWith(
            () => _StaticFavouritesNotifier(const FavouritesState()),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byTooltip('Open match').first),
        matchesSemantics(
          label: 'Open match',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byTooltip('Open pools').first),
        matchesSemantics(
          label: 'Open pools',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });
  });
}

class _StaticProfileIdentityController extends ProfileIdentityController {
  _StaticProfileIdentityController(this._team);

  final FavoriteTeamRecordDto? _team;

  @override
  Future<FavoriteTeamRecordDto?> build() async => _team;
}

class _StaticFavouritesNotifier extends FavouritesNotifier {
  _StaticFavouritesNotifier(this._state);

  final FavouritesState _state;

  @override
  Future<FavouritesState> build() async => _state;
}

class _StaticSupportedTeamsController extends SupportedTeamsService {
  _StaticSupportedTeamsController(this._teamIds);

  final Set<String> _teamIds;

  @override
  FutureOr<Set<String>> build() async => _teamIds;
}

class _StaticGlobalLeaderboard extends GlobalLeaderboard {
  _StaticGlobalLeaderboard(this._entries);

  final List<Map<String, dynamic>> _entries;

  @override
  FutureOr<List<Map<String, dynamic>>> build() async => _entries;
}
