import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/widgets/common/fz_animated_entry.dart';
import 'package:fanzone/features/home/screens/home_feed_screen.dart';
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
import 'package:fanzone/services/wallet_service.dart';

import 'support/test_app.dart';
import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  testWidgets('home feed meets labeled tap target and contrast guidelines', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final feedFilter = MatchesFilter(
      dateFrom: today.toIso8601String(),
      dateTo: today.add(const Duration(days: 7)).toIso8601String(),
      limit: 200,
      ascending: true,
    );

    await pumpAppScreen(
      tester,
      const HomeFeedScreen(),
      overrides: [
        matchesProvider(
          feedFilter,
        ).overrideWith((ref) async => [sampleMatch(date: today)]),
        competitionsProvider.overrideWith((ref) async => [sampleCompetition()]),
      ],
    );
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('predict screen meets labeled tap target guideline', (
    tester,
  ) async {
    await pumpAppScreen(
      tester,
      const PredictScreen(),
      overrides: [
        poolServiceProvider.overrideWith(() => FakePoolService([samplePool()])),
        myEntriesProvider.overrideWith(() => FakeMyEntries([])),
        userCurrencyProvider.overrideWith((ref) async => 'EUR'),
      ],
    );
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wallet screen meets labeled tap target guideline', (
    tester,
  ) async {
    await pumpAppScreen(
      tester,
      const WalletScreen(),
      overrides: [
        walletServiceProvider.overrideWith(() => FakeWalletService(420)),
        transactionServiceProvider.overrideWith(
          () => FakeTransactionService([sampleWalletTransaction()]),
        ),
        isAuthenticatedProvider.overrideWith((ref) => true),
        userCurrencyProvider.overrideWith((ref) async => 'EUR'),
      ],
    );
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile screen meets labeled tap target guideline', (
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

    final semantics = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('match detail screen meets labeled tap target guideline', (
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
        matchAlertEnabledProvider(match.id).overrideWith((ref) async => false),
      ],
    );
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reduced motion skips staged entry animations', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          disableAnimations: true,
          accessibleNavigation: true,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FzAnimatedEntry(
            index: 3,
            child: Text('Reduced Motion Target'),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(FzAnimatedEntry), findsOneWidget);
    expect(find.text('Reduced Motion Target'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FzAnimatedEntry),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FzAnimatedEntry),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
  });
}
