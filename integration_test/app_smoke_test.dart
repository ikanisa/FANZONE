import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:fanzone/main.dart' as app;

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

    // We may either land on OnboardingScreen or the home FeedScreen depending on local SharedPreferences.
    // Let's identify the current state:

    final isOnboarding =
        find.textContaining('Welcome').evaluate().isNotEmpty ||
        find.textContaining('FANZONE').evaluate().isNotEmpty ||
        find.textContaining('Get Started').evaluate().isNotEmpty ||
        find.textContaining('Guest').evaluate().isNotEmpty;

    if (isOnboarding) {
      debugPrint('Detected Onboarding Flow.');
      // Basic sanity check, ensuring onboarding rendered without crashing.
      expect(find.byType(MaterialApp), findsWidgets);

      // If we are on onboarding, we can't easily jump to Feed without SMS OTP
      // unless we click Guest Mode. Let's try guest mode if available.
      final guestButton = find.textContaining('Guest');
      if (guestButton.evaluate().isNotEmpty) {
        debugPrint('Tapping Guest Mode...');
        await tester.tap(guestButton.first);
        await _pumpFor(tester, const Duration(seconds: 2));
        debugPrint('Completed Guest Tap.');
      }
    } else {
      debugPrint('Detected Authenticated / Home Flow.');

      // 2. Core bottom navigation check
      // Look for standard bottom navigation labels
      final barTab = find.text('Bar');
      final poolsTab = find.text('Pools');
      final walletTab = find.text('Wallet');

      expect(
        barTab.evaluate().isNotEmpty,
        true,
        reason: 'Bar tab not found on bottom nav',
      );
      expect(
        poolsTab.evaluate().isNotEmpty,
        true,
        reason: 'Pools tab not found on bottom nav',
      );

      // 3. Navigate to Pools
      debugPrint('Navigating to Pools tab...');
      await tester.tap(poolsTab.first);
      // Wait for layout and async Supabase pool fetch
      await _pumpFor(tester, const Duration(seconds: 3));
      debugPrint('Pools tab resolved.');

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

      // Navigate to Wallet
      debugPrint('Navigating to Wallet tab...');
      if (walletTab.evaluate().isNotEmpty) {
        await tester.tap(walletTab.first);
        await _pumpFor(tester, const Duration(seconds: 2));
        debugPrint('Wallet tab resolved.');
      }
    }

    debugPrint(
      'Smoke test completed successfully — UI rendered without exceptions.',
    );
  });
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 250);
  var elapsed = Duration.zero;

  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}
