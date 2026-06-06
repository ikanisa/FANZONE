import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:fanzone/main.dart' as app;
import 'package:fanzone/app_router.dart' as app_router;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E Smoke Test - Launch and Nav Integrity', (
    WidgetTester tester,
  ) async {
    debugPrint('Starting FANZONE e2e test...');

    // 1. Boot Application
    await app.main();

    // Wait for native splash to clear, Supabase to init, and first frame to render
    await _pumpFor(tester, const Duration(seconds: 5));
    debugPrint('App initialized and pumped.');

    // We may either land on OnboardingScreen or the home FeedScreen depending
    // on local SharedPreferences. Wait for a known production surface instead
    // of assuming every non-onboarding frame is authenticated home.
    final homeTab = find.byKey(const ValueKey('bottom_nav_home'));
    final playTab = find.byKey(const ValueKey('bottom_nav_arena'));
    final settingsTab = find.byKey(const ValueKey('bottom_nav_settings'));
    bool hasProductionShell() =>
        homeTab.evaluate().isNotEmpty &&
        playTab.evaluate().isNotEmpty &&
        settingsTab.evaluate().isNotEmpty;
    bool isOnboarding() =>
        !hasProductionShell() &&
        (find
                .byKey(const ValueKey('onboarding_get_started'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey('onboarding_phone_number'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey('onboarding_otp_digit_0'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey('fan_profile_team_search'))
                .evaluate()
                .isNotEmpty ||
            find.textContaining('WHATSAPP').evaluate().isNotEmpty ||
            find.textContaining('Welcome').evaluate().isNotEmpty ||
            find.textContaining('Get Started').evaluate().isNotEmpty ||
            find.textContaining('Guest').evaluate().isNotEmpty);

    await _pumpUntil(
      tester,
      () => hasProductionShell() || isOnboarding(),
      timeout: const Duration(seconds: 12),
    );

    if (isOnboarding()) {
      debugPrint('Detected Onboarding Flow.');
      // Basic sanity check, ensuring onboarding rendered without crashing.
      expect(find.byType(MaterialApp), findsWidgets);

      await _completeDevOnboarding(tester);
      await _pumpUntil(
        tester,
        hasProductionShell,
        timeout: const Duration(seconds: 30),
      );
      expect(
        hasProductionShell(),
        true,
        reason: 'Production shell did not load after dev onboarding',
      );
    } else {
      debugPrint('Detected Authenticated / Home Flow.');

      expect(
        hasProductionShell(),
        true,
        reason: 'Production three-tab bottom nav was not found',
      );

      debugPrint('Navigating to Play tab...');
      await tester.tap(playTab.first);
      await _pumpFor(tester, const Duration(seconds: 3));
      debugPrint('Play tab resolved.');

      final playGamePreview = find.byKey(
        const ValueKey(
          'play_game_preview_00000000-0000-4000-8000-000000000501',
        ),
      );
      await _pumpUntil(
        tester,
        () => playGamePreview.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 12),
      );
      expect(
        playGamePreview.evaluate().isNotEmpty,
        true,
        reason: 'Play tab did not render the live game preview',
      );
      for (final gameId in [
        '00000000-0000-4000-8000-000000000504',
        '00000000-0000-4000-8000-000000000505',
      ]) {
        expect(
          find
              .byKey(ValueKey('play_game_preview_$gameId'))
              .evaluate()
              .isNotEmpty,
          true,
          reason: 'Play tab did not render game preview $gameId',
        );
      }

      // Ensure there are no error widgets. Our StateView handles errors.
      // We can check that the screen rendered fully.
      final noOpenPools = find.textContaining('No pools available');
      final noCuratedMatches = find.textContaining(
        'Curated matches will appear here once they are published.',
      );

      if (noOpenPools.evaluate().isNotEmpty ||
          noCuratedMatches.evaluate().isNotEmpty) {
        debugPrint(
          'Pools empty states are active (expected if no curated matches are ready).',
        );
      } else {
        debugPrint('Pools content found and rendered.');
      }

      debugPrint('Navigating to Settings tab...');
      await tester.tap(settingsTab.first);
      await _pumpFor(tester, const Duration(seconds: 2));
      debugPrint('Settings tab resolved.');

      expect(find.text('SETTINGS'), findsWidgets);
    }

    await _runCoreHospitalitySmoke(tester);

    debugPrint(
      'Smoke test completed successfully — UI rendered without exceptions.',
    );
  });
}

Future<void> _completeDevOnboarding(WidgetTester tester) async {
  final getStarted = find.byKey(const ValueKey('onboarding_get_started'));
  if (getStarted.evaluate().isNotEmpty) {
    debugPrint('Starting onboarding...');
    await tester.tap(getStarted.first);
    await _pumpFor(tester, const Duration(seconds: 1));
  }

  final phoneField = find.byKey(const ValueKey('onboarding_phone_number'));
  await _pumpUntil(
    tester,
    () => phoneField.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 8),
  );
  expect(
    phoneField.evaluate().isNotEmpty,
    true,
    reason: 'Onboarding phone field did not appear',
  );

  debugPrint('Entering development WhatsApp number...');
  await tester.enterText(phoneField.first, '7718613');
  await _pumpFor(tester, const Duration(milliseconds: 500));

  final sendOtp = find.byKey(const ValueKey('onboarding_send_otp'));
  expect(sendOtp.evaluate().isNotEmpty, true, reason: 'Send OTP missing');
  await tester.tap(sendOtp.first);
  await _pumpFor(tester, const Duration(seconds: 1));

  final firstOtpField = find.byKey(const ValueKey('onboarding_otp_digit_0'));
  await _pumpUntil(
    tester,
    () => firstOtpField.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 8),
  );
  expect(
    firstOtpField.evaluate().isNotEmpty,
    true,
    reason: 'OTP step did not appear after Send OTP',
  );

  debugPrint('Entering development OTP...');
  const otp = '123456';
  for (var i = 0; i < otp.length; i += 1) {
    await tester.enterText(
      find.byKey(ValueKey('onboarding_otp_digit_$i')).first,
      otp[i],
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  final verifyOtp = find.byKey(const ValueKey('onboarding_verify_otp'));
  expect(verifyOtp.evaluate().isNotEmpty, true, reason: 'Verify OTP missing');
  await tester.tap(verifyOtp.first);

  final teamSearch = find.byKey(const ValueKey('fan_profile_team_search'));
  await _pumpUntil(
    tester,
    () => teamSearch.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  expect(
    teamSearch.evaluate().isNotEmpty,
    true,
    reason: 'Fan profile team selector did not appear',
  );

  final topEuropeanStep = find.byKey(
    const ValueKey('fan_profile_step_topEuropean'),
  );
  if (topEuropeanStep.evaluate().isEmpty) {
    debugPrint('Selecting local team from Supabase-backed catalog...');
    await _selectFanProfileTeam(tester, query: 'Valletta');
    await _pumpUntil(
      tester,
      () => topEuropeanStep.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 12),
    );
    expect(
      topEuropeanStep.evaluate().isNotEmpty,
      true,
      reason: 'Fan profile did not advance to top European team selection',
    );
  }

  debugPrint('Selecting top European team from Supabase-backed catalog...');
  await _selectFanProfileTeam(tester, query: 'Arsenal');

  final saveProfile = find.byKey(const ValueKey('fan_profile_save'));
  expect(
    saveProfile.evaluate().isNotEmpty,
    true,
    reason: 'Fan profile save button missing',
  );
  await tester.ensureVisible(saveProfile.first);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  debugPrint('Saving fan profile...');
  await tester.tap(saveProfile.first);
  await _pumpFor(tester, const Duration(seconds: 5));
}

Future<void> _selectFanProfileTeam(
  WidgetTester tester, {
  required String query,
}) async {
  final search = find.byKey(const ValueKey('fan_profile_team_search'));
  await _pumpUntil(
    tester,
    () => search.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  await tester.enterText(search.first, query);
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(tester, const Duration(seconds: 1));
  await _tapFirstTeamResult(tester);
  await _pumpFor(tester, const Duration(seconds: 1));
}

Future<void> _tapFirstTeamResult(WidgetTester tester) async {
  Finder teamResultFinder() => find.byWidgetPredicate((widget) {
    final key = widget.key;
    return widget is ListTile &&
        key is ValueKey<String> &&
        key.value.startsWith('fan_profile_team_');
  });

  await _pumpUntil(
    tester,
    () => teamResultFinder().evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );

  final results = teamResultFinder();
  expect(
    results.evaluate().isNotEmpty,
    true,
    reason: 'No team rows were available for onboarding selection',
  );
  await tester.ensureVisible(results.first);
  await tester.tap(results.first);
  await tester.pump();
}

Future<void> _runCoreHospitalitySmoke(WidgetTester tester) async {
  debugPrint('Starting core hospitality UAT smoke...');

  app_router.router.go('/pools');
  final playGamePreview = find.byKey(
    const ValueKey('play_game_preview_00000000-0000-4000-8000-000000000501'),
  );
  await _pumpUntil(
    tester,
    () => playGamePreview.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  expect(
    playGamePreview.evaluate().isNotEmpty,
    true,
    reason: 'Play tab did not render the live game preview',
  );
  for (final gameId in [
    '00000000-0000-4000-8000-000000000504',
    '00000000-0000-4000-8000-000000000505',
  ]) {
    final gamePreview = find.byKey(ValueKey('play_game_preview_$gameId'));
    expect(
      gamePreview.evaluate().isNotEmpty,
      true,
      reason: 'Play tab did not render game preview $gameId',
    );
  }
  debugPrint('Play hub rendered three game previews.');

  final uatPoolJoin = find.byKey(
    const ValueKey('pool_join_00000000-0000-4000-8000-000000000401'),
  );
  await tester.dragUntilVisible(
    uatPoolJoin,
    find.byType(ListView).first,
    const Offset(0, -420),
    maxIteration: 8,
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(
    uatPoolJoin.evaluate().isNotEmpty,
    true,
    reason: 'Play hub did not render the UAT pool from Supabase',
  );
  await tester.ensureVisible(uatPoolJoin.first);
  expect(find.text('UAT Home Lions vs Away Harbors'), findsWidgets);
  debugPrint('Play hub rendered Supabase-backed UAT pool.');

  await tester.tap(uatPoolJoin.first);
  final stakeField = find.byKey(const ValueKey('pool_join_stake_field'));
  await _pumpUntil(
    tester,
    () => stakeField.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  expect(
    stakeField.evaluate().isNotEmpty,
    true,
    reason: 'UAT pool join stake field did not render',
  );
  expect(find.text('250 FET'), findsWidgets);
  debugPrint('UAT pool wallet before stake: 250 FET.');
  await tester.enterText(stakeField.first, '25');
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(tester, const Duration(milliseconds: 500));

  final confirmJoin = find.byKey(const ValueKey('pool_join_confirm'));
  await tester.dragUntilVisible(
    confirmJoin,
    find.byType(ListView).first,
    const Offset(0, -260),
    maxIteration: 8,
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(
    confirmJoin.evaluate().isNotEmpty,
    true,
    reason: 'UAT pool join confirm button did not render',
  );
  await tester.ensureVisible(confirmJoin.first);
  await tester.tap(confirmJoin.first);
  final joinedEntry = find.byKey(
    const ValueKey('pool_entry_state_00000000-0000-4000-8000-000000000401'),
  );
  await _pumpUntil(
    tester,
    () => joinedEntry.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  expect(
    joinedEntry.evaluate().isNotEmpty,
    true,
    reason: 'UAT pool entry state did not render after join',
  );
  expect(find.text('Joined'), findsWidgets);
  expect(find.textContaining('25 FET'), findsWidgets);
  debugPrint('Supabase-backed UAT pool join completed with dev FET stake.');

  app_router.router.go('/venues');
  await _pumpUntil(
    tester,
    () =>
        find.byKey(const ValueKey('venue_search_field')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  expect(
    find.byKey(const ValueKey('venue_search_field')).evaluate().isNotEmpty,
    true,
    reason: 'Venue discovery search did not render',
  );

  await tester.enterText(
    find.byKey(const ValueKey('venue_search_field')).first,
    'UAT Live',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(tester, const Duration(seconds: 2));

  final openMenu = find.byKey(
    const ValueKey('venue_open_menu_00000000-0000-4000-8000-000000000301'),
  );
  await _pumpUntil(
    tester,
    () => openMenu.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  expect(openMenu.evaluate().isNotEmpty, true, reason: 'UAT venue not visible');
  debugPrint('Venue discovery rendered UAT bar.');
  await tester.ensureVisible(openMenu.first);
  await tester.tap(openMenu.first);

  final addBurger = find.byKey(
    const ValueKey('menu_item_add_00000000-0000-4000-8000-000000000304'),
  );
  await _pumpUntil(
    tester,
    () => addBurger.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 15),
  );
  expect(
    addBurger.evaluate().isNotEmpty,
    true,
    reason: 'UAT menu item did not render',
  );
  debugPrint('Menu rendered UAT item.');
  await tester.ensureVisible(addBurger.first);
  await tester.tap(addBurger.first);
  await _pumpFor(tester, const Duration(seconds: 1));

  final checkoutPill = find.byKey(const ValueKey('cart_pill_checkout'));
  await _pumpUntil(
    tester,
    () => checkoutPill.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 8),
  );
  expect(checkoutPill.evaluate().isNotEmpty, true, reason: 'Cart pill missing');
  await tester.tap(checkoutPill.first);

  final tableField = find.byKey(const ValueKey('checkout_table_number'));
  await _pumpUntil(
    tester,
    () => tableField.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 10),
  );
  expect(
    tableField.evaluate().isNotEmpty,
    true,
    reason: 'Checkout table-number field missing',
  );
  await tester.enterText(tableField.first, 'UAT-1');
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(tester, const Duration(milliseconds: 500));

  final cashPayment = find.byKey(const ValueKey('checkout_payment_cash'));
  await tester.ensureVisible(cashPayment.first);
  await tester.tap(cashPayment.first);
  await _pumpFor(tester, const Duration(milliseconds: 500));

  final placeOrder = find.byKey(const ValueKey('checkout_place_order'));
  await tester.ensureVisible(placeOrder.first);
  await tester.tap(placeOrder.first);

  await _pumpUntil(
    tester,
    () => find
        .byKey(const ValueKey('order_success_receipt'))
        .evaluate()
        .isNotEmpty,
    timeout: const Duration(seconds: 15),
  );
  expect(find.text('Order sent'), findsWidgets);
  debugPrint('Table-number checkout completed with local UAT order.');

  final receipt = find.byKey(const ValueKey('order_success_receipt'));
  await tester.ensureVisible(receipt.first);
  await tester.tap(receipt.first);
  await _pumpUntil(
    tester,
    () => find.text('UAT Burger Combo').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 10),
  );
  expect(find.text('UAT Burger Combo'), findsWidgets);
  debugPrint('Receipt rendered UAT order item.');

  app_router.router.go('/wallet');
  await _pumpUntil(
    tester,
    () => find.byKey(const ValueKey('wallet_screen')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 10),
  );
  expect(find.text('REWARDS'), findsWidgets);
  expect(
    find.byKey(const ValueKey('wallet-total-balance-value')),
    findsWidgets,
  );
  await _pumpUntil(
    tester,
    () => find.text('FET 225').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 8),
  );
  expect(find.text('FET 225'), findsWidgets);
  final poolEntryTransaction = find.text('Pool entry');
  await tester.dragUntilVisible(
    poolEntryTransaction,
    find.byKey(const ValueKey('wallet_screen')),
    const Offset(0, -260),
    maxIteration: 8,
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(poolEntryTransaction, findsWidgets);
  expect(find.text('-FET 25'), findsWidgets);
  debugPrint('UAT pool wallet after stake: FET 225 with -FET 25 entry.');
  debugPrint('Rewards ledger rendered.');

  app_router.router.go('/games');
  await _pumpUntil(
    tester,
    () => find.byKey(const ValueKey('games_screen')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 10),
  );
  final uatGame = find.byKey(
    const ValueKey('game_card_00000000-0000-4000-8000-000000000501'),
  );
  await _pumpUntil(
    tester,
    () => uatGame.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 12),
  );
  expect(uatGame.evaluate().isNotEmpty, true, reason: 'UAT game not visible');
  final songGuess = find.byKey(
    const ValueKey('game_card_00000000-0000-4000-8000-000000000504'),
  );
  await _pumpUntil(
    tester,
    () => songGuess.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 8),
  );
  expect(
    songGuess.evaluate().isNotEmpty,
    true,
    reason: 'Active game listing did not render Song Guess',
  );

  final soonFilter = find.byKey(const ValueKey('games_filter_upcoming'));
  expect(soonFilter.evaluate().isNotEmpty, true, reason: 'Soon filter missing');
  await tester.tap(soonFilter.first);
  await _pumpFor(tester, const Duration(seconds: 1));

  final musicBingo = find.byKey(
    const ValueKey('game_card_00000000-0000-4000-8000-000000000505'),
  );
  await _pumpUntil(
    tester,
    () => musicBingo.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 8),
  );
  expect(
    musicBingo.evaluate().isNotEmpty,
    true,
    reason: 'Soon game listing did not render Music Bingo',
  );
  debugPrint('Free-to-play game listing rendered all three games.');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  const step = Duration(milliseconds: 250);
  var elapsed = Duration.zero;

  while (elapsed < timeout) {
    if (condition()) return;
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 250);
  var elapsed = Duration.zero;

  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}
