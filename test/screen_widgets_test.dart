import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/features/home/screens/home_screen.dart';
import 'package:fanzone/features/home/screens/match_detail_screen.dart';
import 'package:fanzone/features/predict/screens/predict_screen.dart';
import 'package:fanzone/features/profile/screens/profile_screen.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/models/match_model.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/competitions_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/matches_provider.dart';
import 'package:fanzone/services/notification_service.dart';
import 'package:fanzone/services/pool_service.dart';
import 'package:fanzone/services/prediction_slip_service.dart';
import 'package:fanzone/services/wallet_service.dart';

import 'support/test_app.dart';
import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('screen widgets', () {
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
          myPredictionSlipsProvider.overrideWith((ref) async => const []),
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
      await pumpAppScreen(
        tester,
        const ProfileScreen(),
        overrides: [
          walletServiceProvider.overrideWith(() => FakeWalletService(980)),
          isAuthenticatedProvider.overrideWith((ref) => true),
          currentUserProvider.overrideWith((ref) => null),
          userFanIdProvider.overrideWith((ref) async => '123456'),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Fan ID: 123456'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Membership'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Membership'), findsOneWidget);
      expect(find.text('My Pools'), findsOneWidget);
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
          matchAlertEnabledProvider(
            match.id,
          ).overrideWith((ref) async => false),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Liverpool'), findsAtLeastNWidgets(1));
      expect(find.text('Arsenal'), findsAtLeastNWidgets(1));
      expect(find.text('Overview'), findsOneWidget);
      expect(find.byTooltip('Share match'), findsOneWidget);
    });
  });
}
