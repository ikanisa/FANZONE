import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/data/team_search_database.dart';
import 'package:fanzone/features/fixtures/screens/fixtures_screen.dart';
import 'package:fanzone/features/home/screens/home_feed_screen.dart';
import 'package:fanzone/features/home/screens/home_screen.dart';
import 'package:fanzone/features/home/screens/match_detail_screen.dart';
import 'package:fanzone/features/predict/screens/predict_screen.dart';
import 'package:fanzone/features/profile/providers/profile_identity_provider.dart';
import 'package:fanzone/features/profile/screens/profile_screen.dart';
import 'package:fanzone/models/featured_event_model.dart';
import 'package:fanzone/models/match_advanced_stats_model.dart';
import 'package:fanzone/models/match_odds_model.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/models/match_model.dart';
import 'package:fanzone/models/match_player_stats_model.dart';
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
import 'package:fanzone/services/notification_service.dart';
import 'package:fanzone/services/pool_service.dart';
import 'package:fanzone/services/team_community_service.dart';
import 'package:fanzone/services/wallet_service.dart';

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
            matchesByDateProvider(
              selectedDate,
            ).overrideWith((ref) => Stream.value([liveMatch, upcomingMatch])),
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

        expect(find.text('Predictions'), findsOneWidget);
        expect(find.text('Live Action'), findsOneWidget);
        expect(find.text('Upcoming'), findsOneWidget);
        expect(find.byTooltip('Create pool'), findsOneWidget);
        expect(find.text('MATCHDAY HUB'), findsNothing);
      },
    );

    testWidgets('home screen renders grouped live and upcoming matches', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final competition = sampleCompetition();
      final liveMatch = sampleMatch(
        id: 'match_live',
        date: today,
        status: 'live',
        ftHome: 2,
        ftAway: 1,
        kickoffTime: '20:00',
      );
      final upcomingMatch = sampleMatch(
        id: 'match_upcoming',
        competitionId: competition.id,
        date: today,
        homeTeam: 'Barcelona',
        awayTeam: 'Real Madrid',
        kickoffTime: '21:00',
      );

      await pumpAppScreen(
        tester,
        const HomeScreen(),
        overrides: [
          matchesByDateProvider(
            today,
          ).overrideWith((ref) => Stream.value([liveMatch, upcomingMatch])),
          competitionsProvider.overrideWith((ref) async => [competition]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('MATCHES'), findsOneWidget);
      expect(find.text('Liverpool'), findsAtLeastNWidgets(1));
      expect(find.text('Barcelona'), findsAtLeastNWidgets(1));
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Live · 1'), findsOneWidget);
    });

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
      expect(find.textContaining('Liverpool vs Arsenal'), findsOneWidget);
      expect(find.byTooltip('Create pool'), findsWidgets);
    });

    testWidgets('predict create route opens the pool creation sheet', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const PredictScreen(openCreateSheet: true),
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

      expect(find.text('YOUR SCORE PREDICTION'), findsOneWidget);
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
      expect(find.text('Fan ID: 123456'), findsOneWidget);
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
      expect(find.text('Stats'), findsOneWidget);
      expect(find.byTooltip('Share match'), findsOneWidget);
    });

    testWidgets(
      'fixtures screen defaults to competitions and can switch views',
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
        expect(find.text('Europe'), findsOneWidget);
        expect(find.text('For You'), findsOneWidget);

        await tester.tap(find.byTooltip('Matches'));
        await tester.pumpAndSettle();

        expect(find.text('This Week'), findsOneWidget);
        expect(find.textContaining('Today'), findsOneWidget);
        expect(find.byTooltip('Search fixtures'), findsOneWidget);
      },
    );
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
