import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/data/team_search_database.dart';
import 'package:fanzone/features/fixtures/screens/fixtures_screen.dart';
import 'package:fanzone/features/home/screens/home_feed_screen.dart';
import 'package:fanzone/features/home/screens/match_detail_screen.dart';
import 'package:fanzone/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:fanzone/features/predict/screens/predict_screen.dart';
import 'package:fanzone/features/profile/providers/profile_identity_provider.dart';
import 'package:fanzone/features/profile/screens/notifications_screen.dart';
import 'package:fanzone/features/profile/screens/profile_screen.dart';
import 'package:fanzone/features/settings/screens/privacy_settings_screen.dart';
import 'package:fanzone/features/teams/screens/team_profile_canonical_screen.dart';
import 'package:fanzone/models/featured_event_model.dart';
import 'package:fanzone/models/notification_model.dart';
import 'package:fanzone/models/prediction_engine_output_model.dart';
import 'package:fanzone/models/standing_row_model.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/models/team_form_feature_model.dart';
import 'package:fanzone/models/team_model.dart';
import 'package:fanzone/models/user_prediction_model.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/competitions_provider.dart';
import 'package:fanzone/providers/crowd_prediction_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/favorite_teams_provider.dart';
import 'package:fanzone/providers/favourites_provider.dart';
import 'package:fanzone/providers/featured_events_provider.dart';
import 'package:fanzone/providers/home_feed_provider.dart';
import 'package:fanzone/providers/market_preferences_provider.dart';
import 'package:fanzone/providers/matches_provider.dart';
import 'package:fanzone/providers/standings_provider.dart';
import 'package:fanzone/providers/teams_provider.dart';
import 'package:fanzone/services/leaderboard_service.dart';
import 'package:fanzone/services/notification_service.dart';
import 'package:fanzone/services/prediction_service.dart';
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
          homeTeamId: 'test-club-a',
          awayTeamId: 'test-club-b',
          ftHome: 1,
          ftAway: 0,
        );
        final upcomingMatch = sampleMatch(
          id: 'home_upcoming',
          date: selectedDate,
          homeTeamId: 'test-club-c',
          awayTeamId: 'test-club-d',
          homeTeam: 'Test Club C',
          awayTeam: 'Test Club D',
        );
        final filteredOutMatch = sampleMatch(
          id: 'home_filtered_out',
          date: selectedDate,
          homeTeamId: 'test-club-e',
          awayTeamId: 'test-club-f',
          homeTeam: 'Test Club E',
          awayTeam: 'Test Club F',
        );
        const favoriteTeam = FavoriteTeamRecordDto(
          teamId: 'test-club-c',
          teamName: 'Test Club C',
          teamShortName: 'Club C',
          source: 'local',
        );
        initTeamSearchDatabase(
          catalog: TeamSearchCatalog(
            const [
              OnboardingTeam(
                id: 'test-club-a',
                name: 'Test Club A',
                country: 'Test Country',
                shortNameOverride: 'TCA',
              ),
              OnboardingTeam(
                id: 'test-club-b',
                name: 'Test Club B',
                country: 'Test Country',
                shortNameOverride: 'TCB',
              ),
              OnboardingTeam(
                id: 'test-club-c',
                name: 'Test Club C',
                country: 'Test Country',
                shortNameOverride: 'TCC',
              ),
              OnboardingTeam(
                id: 'test-club-e',
                name: 'Test Club E',
                country: 'Test Country',
              ),
              OnboardingTeam(
                id: 'test-club-f',
                name: 'Test Club F',
                country: 'Test Country',
              ),
            ],
            popularTeams: const [
              OnboardingTeam(
                id: 'test-club-a',
                name: 'Test Club A',
                country: 'Test Country',
                shortNameOverride: 'TCA',
              ),
              OnboardingTeam(
                id: 'test-club-b',
                name: 'Test Club B',
                country: 'Test Country',
                shortNameOverride: 'TCB',
              ),
            ],
          ),
        );
        addTearDown(() {
          initTeamSearchDatabase(catalog: TeamSearchCatalog.defaults());
        });

        await pumpAppScreen(
          tester,
          const HomeFeedScreen(),
          overrides: [
            matchesProvider(feedFilter).overrideWith(
              (ref) async => [liveMatch, upcomingMatch, filteredOutMatch],
            ),
            favoriteTeamRecordsProvider.overrideWith(
              (ref) async => const [favoriteTeam],
            ),
            homeDefaultTeamsProvider.overrideWith(
              (ref) async => const [
                OnboardingTeam(
                  id: 'test-club-a',
                  name: 'Test Club A',
                  country: 'Test Country',
                  shortNameOverride: 'TCA',
                  aliases: ['Test Club A FC', 'Alpha Side'],
                  popularRank: 6,
                ),
                OnboardingTeam(
                  id: 'test-club-b',
                  name: 'Test Club B',
                  country: 'Test Country',
                  shortNameOverride: 'TCB',
                  aliases: ['Test Club B FC', 'Bravo Side'],
                  popularRank: 3,
                ),
              ],
            ),
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
        expect(
          find.byKey(const ValueKey('home-match-card-home_live')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-match-card-home_upcoming')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-match-card-home_filtered_out')),
          findsNothing,
        );
        expect(find.text('PREDICT'), findsNWidgets(2));
        expect(find.text('MATCH'), findsNWidgets(2));
        expect(find.text('FREE ENTRY'), findsNothing);
        expect(find.text('MATCHDAY HUB'), findsNothing);
      },
    );

    testWidgets(
      'leaderboard renders the lean global podium and pinned user card',
      (tester) async {
        final entries = <Map<String, dynamic>>[
          {'rank': 1, 'name': 'SpartanKing', 'fet': 15200},
          {'rank': 2, 'name': 'LeagueFan', 'fet': 12400},
          {'rank': 3, 'name': 'NorthCurve', 'fet': 10100},
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

        expect(find.text('Leaderboard'), findsOneWidget);
        expect(find.byIcon(LucideIcons.trophy), findsNWidgets(3));
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Accuracy 68%'), findsOneWidget);
        expect(find.text('SpartanKing'), findsOneWidget);
      },
    );

    testWidgets('predict screen renders the lean picks workflow', (
      tester,
    ) async {
      final match = sampleMatch();
      final competition = sampleCompetition();

      await pumpAppScreen(
        tester,
        const PredictScreen(),
        overrides: [
          upcomingMatchesProvider.overrideWith((ref) => Stream.value([match])),
          myPredictionsProvider.overrideWith(
            (ref) async => const <UserPredictionModel>[],
          ),
          competitionProvider(
            competition.id,
          ).overrideWith((ref) async => competition),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Predict'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('My picks'), findsOneWidget);
      expect(find.text('Test Club A'), findsAtLeastNWidgets(1));
      expect(find.text('Test Club B'), findsAtLeastNWidgets(1));
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Make pick'), findsOneWidget);
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
        find.text('Prediction reward'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Prediction reward'), findsOneWidget);
    });

    testWidgets('profile screen renders account sections for signed-in users', (
      tester,
    ) async {
      const selectedTeam = FavoriteTeamRecordDto(
        teamId: 'test-club-a',
        teamName: 'Test Club A',
        teamShortName: 'TCA',
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
          bootstrapConfigProvider.overrideWithValue(
            BootstrapConfig(
              regions: const {},
              phonePresets: const {},
              currencyDisplay: const {},
              featureFlags: const {
                'predictions': true,
                'wallet': true,
                'leaderboard': true,
                'notifications': true,
              },
              appConfig: const {},
              launchMoments: const [],
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Fan ID 123456'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Predictions'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Select Identity'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-identity-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Select Identity'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
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
      expect(find.text('Display Name on Leaderboards'), findsOneWidget);
      expect(find.text('Allow Friends to Find Me'), findsOneWidget);
      expect(
        find.text('* Verification required to change visibility settings.'),
        findsOneWidget,
      );
    });

    testWidgets('team profile screen restores the original tab contract', (
      tester,
    ) async {
      const team = TeamModel(
        id: 'test-club-c',
        name: 'Test Club C',
        shortName: 'TCC',
        country: 'Test Country',
        leagueName: 'Test Competition Regional',
        competitionIds: ['competition_regional'],
        fanCount: 1240,
      );
      final match = sampleMatch(
        id: 'regional_match',
        competitionId: 'competition_regional',
        homeTeam: 'Test Club C',
        awayTeam: 'Test Club E FC',
        status: 'finished',
        ftHome: 2,
        ftAway: 0,
      );

      await pumpAppScreen(
        tester,
        const TeamProfileScreen(teamId: 'test-club-c'),
        overrides: [
          teamProvider(team.id).overrideWith((ref) async => team),
          teamsProvider.overrideWith((ref) async => const [team]),
          competitionsProvider.overrideWith(
            (ref) async => [
              sampleCompetition(
                id: 'competition_regional',
                name: 'Test Competition Regional',
                shortName: 'TCR',
                country: 'Test Country',
              ),
            ],
          ),
          teamMatchesProvider(
            team.id,
          ).overrideWith((ref) => Stream.value([match])),
          isAuthenticatedProvider.overrideWith((ref) => true),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Club C'), findsWidgets);
      expect(find.text('Team Snapshot'), findsOneWidget);
      expect(find.text('Recent Fixtures'), findsOneWidget);
      expect(find.text('Test Competition Regional'), findsWidgets);
      expect(find.text('Test Club E FC'), findsOneWidget);
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

      expect(find.text('Team'), findsOneWidget);
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
                type: 'prediction_scored',
                title: 'Prediction scored',
                body: 'Your derby pick has been graded.',
                sentAt: DateTime(2026, 4, 19, 12),
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Prediction scored'), findsOneWidget);
    });

    testWidgets('match detail screen renders the lean prediction center', (
      tester,
    ) async {
      final match = sampleMatch(
        id: 'detail_match',
        status: 'live',
        ftHome: 2,
        ftAway: 1,
      );
      final competition = sampleCompetition();
      final engine = PredictionEngineOutputModel(
        id: 'engine_1',
        matchId: match.id,
        modelVersion: 'simple_form_v1',
        homeWinScore: 0.54,
        drawScore: 0.24,
        awayWinScore: 0.22,
        over25Score: 0.61,
        bttsScore: 0.58,
        predictedHomeGoals: 2,
        predictedAwayGoals: 1,
        confidenceLabel: 'medium',
        generatedAt: DateTime(2026, 4, 19, 12),
      );
      final myPrediction = UserPredictionModel(
        id: 'prediction_1',
        userId: 'user_1',
        matchId: match.id,
        predictedResultCode: 'H',
        predictedOver25: true,
        predictedBtts: true,
        predictedHomeGoals: 2,
        predictedAwayGoals: 1,
        pointsAwarded: 0,
        rewardStatus: 'pending',
        createdAt: DateTime(2026, 4, 19, 10),
        updatedAt: DateTime(2026, 4, 19, 10),
      );
      final formRows = <TeamFormFeatureModel>[
        const TeamFormFeatureModel(
          id: 'form_home',
          matchId: 'detail_match',
          teamId: 'test-club-a',
          last5Points: 10,
          last5Wins: 3,
          last5Draws: 1,
          last5Losses: 1,
          last5GoalsFor: 9,
          last5GoalsAgainst: 4,
          last5CleanSheets: 2,
          last5FailedToScore: 1,
          homeFormLast5: 10,
          awayFormLast5: 0,
          over25Last5: 3,
          bttsLast5: 2,
        ),
        const TeamFormFeatureModel(
          id: 'form_away',
          matchId: 'detail_match',
          teamId: 'test-club-b',
          last5Points: 8,
          last5Wins: 2,
          last5Draws: 2,
          last5Losses: 1,
          last5GoalsFor: 7,
          last5GoalsAgainst: 5,
          last5CleanSheets: 1,
          last5FailedToScore: 1,
          homeFormLast5: 0,
          awayFormLast5: 8,
          over25Last5: 2,
          bttsLast5: 3,
        ),
      ];
      final standings = <StandingRowModel>[
        const StandingRowModel(
          competitionId: 'competition_alpha',
          season: '2025/26',
          teamId: 'test-club-a',
          teamName: 'Test Club A',
          position: 1,
          played: 30,
          won: 21,
          drawn: 6,
          lost: 3,
          goalsFor: 68,
          goalsAgainst: 28,
          goalDifference: 40,
          points: 69,
        ),
        const StandingRowModel(
          competitionId: 'competition_alpha',
          season: '2025/26',
          teamId: 'test-club-b',
          teamName: 'Test Club B',
          position: 2,
          played: 30,
          won: 19,
          drawn: 7,
          lost: 4,
          goalsFor: 62,
          goalsAgainst: 30,
          goalDifference: 32,
          points: 64,
        ),
      ];

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
          predictionEngineOutputProvider(
            match.id,
          ).overrideWith((ref) async => engine),
          myPredictionForMatchProvider(
            match.id,
          ).overrideWith((ref) async => myPrediction),
          crowdPredictionProvider(match.id).overrideWith(
            (ref) async =>
                const CrowdPrediction(home: 52, draw: 24, away: 24, total: 180),
          ),
          matchFormFeaturesProvider(
            match.id,
          ).overrideWith((ref) async => formRows),
          competitionStandingsProvider(
            CompetitionStandingsFilter(
              competitionId: competition.id,
              season: match.season,
            ),
          ).overrideWith((ref) async => standings),
        ],
      );
      // Use explicit pump() instead of pumpAndSettle() because stream-based
      // providers (matchDetailProvider, competitionMatchesProvider) leave a
      // polling timer that triggers 'Timer still pending' assertions.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Club A'), findsAtLeastNWidgets(1));
      expect(find.text('Test Club B'), findsAtLeastNWidgets(1));
      expect(find.text('Prediction engine'), findsOneWidget);
      expect(find.text('Community picks'), findsOneWidget);
      expect(find.text('Your prediction'), findsOneWidget);
      expect(find.text('Recent form'), findsOneWidget);
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
        final regionalLeague = sampleCompetition(
          id: 'competition_regional',
          name: 'Test Competition Regional',
          shortName: 'TCR',
          country: 'Test Country',
        );

        await pumpAppScreen(
          tester,
          const FixturesScreen(),
          overrides: [
            primaryMarketRegionProvider.overrideWith((ref) => 'europe'),
            competitionsProvider.overrideWith(
              (ref) async => [premierLeague, regionalLeague],
            ),
            top5EuropeanLeaguesProvider.overrideWith(
              (ref) async => [premierLeague],
            ),
            majorCompetitionsProvider.overrideWith((ref) async => [majorEvent]),
            localLeaguesProvider(
              'europe',
            ).overrideWith((ref) async => [regionalLeague]),
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
      'fixtures open predictions action switches to the prediction branch',
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
          id: 'competition_elite',
          name: 'Test Competition Elite',
          shortName: 'TCE',
          country: 'Test Country',
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
                      path: '/predict',
                      builder: (context, state) => const Scaffold(
                        body: Center(child: Text('Predict destination')),
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
                'europe',
              ).overrideWith((ref) async => const []),
              favoriteTeamRecordsProvider.overrideWith((ref) async => const []),
              teamsProvider.overrideWith((ref) async => const []),
              matchesByDateProvider(selectedDate).overrideWith(
                (ref) => Stream.value([
                  sampleMatch(
                    id: 'fixture_match',
                    date: selectedDate,
                    competitionId: 'competition_elite',
                    homeTeam: 'Test Club G',
                    awayTeam: 'Test Club H',
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

        await tester.tap(find.byTooltip('Open predict').first);
        await tester.pumpAndSettle();

        expect(find.text('Predict destination'), findsOneWidget);
      },
    );

    testWidgets('fixture action buttons expose tappable semantics', (
      tester,
    ) async {
      final today = DateTime.now();
      final selectedDate = DateTime(today.year, today.month, today.day);
      final sampleLeague = sampleCompetition(
        id: 'competition_elite',
        name: 'Test Competition Elite',
        shortName: 'TCE',
        country: 'Test Country',
      );

      await pumpAppScreen(
        tester,
        const FixturesScreen(),
        overrides: [
          competitionsProvider.overrideWith((ref) async => [sampleLeague]),
          top5EuropeanLeaguesProvider.overrideWith(
            (ref) async => [sampleLeague],
          ),
          localLeaguesProvider('europe').overrideWith((ref) async => const []),
          favoriteTeamRecordsProvider.overrideWith((ref) async => const []),
          teamsProvider.overrideWith((ref) async => const []),
          matchesByDateProvider(selectedDate).overrideWith(
            (ref) => Stream.value([
              sampleMatch(
                id: 'fixture_match',
                date: selectedDate,
                competitionId: 'competition_elite',
                homeTeam: 'Test Club G',
                awayTeam: 'Test Club H',
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
        tester.getSemantics(find.byTooltip('Open predict').first),
        matchesSemantics(
          label: 'Open predict',
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

class _StaticGlobalLeaderboard extends GlobalLeaderboard {
  _StaticGlobalLeaderboard(this._entries);

  final List<Map<String, dynamic>> _entries;

  @override
  FutureOr<List<Map<String, dynamic>>> build() async => _entries;
}
