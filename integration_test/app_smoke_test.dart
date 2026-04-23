import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:fanzone/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E Smoke Test - Launch and Nav Integrity', (WidgetTester tester) async {
    debugPrint('Starting FANZONE e2e test...');
    
    // 1. Boot Application
    await app.main();
    
    // Wait for native splash to clear, Supabase to init, and first frame to render
    await tester.pumpAndSettle(const Duration(seconds: 5));
    debugPrint('App initialized and pumped.');

    // We may either land on OnboardingScreen or the home FeedScreen depending on local SharedPreferences.
    // Let's identify the current state:
    
    final isOnboarding = find.textContaining('Welcome').evaluate().isNotEmpty || 
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
        await tester.pumpAndSettle();
        debugPrint('Completed Guest Tap.');
      }
      
    } else {
      debugPrint('Detected Authenticated / Home Flow.');
      
      // 2. Feed Screen / Bottom Navigation Check
      // Look for standard bottom navigation labels
      final feedTab = find.text('Feed');
      final predictTab = find.text('Predict');
      final hubTab = find.text('Hub');
      
      expect(feedTab.evaluate().isNotEmpty, true, reason: 'Feed tab not found on bottom nav');
      expect(predictTab.evaluate().isNotEmpty, true, reason: 'Predict tab not found on bottom nav');
      
      // 3. Navigate to Predict
      debugPrint('Navigating to Predict Tab...');
      await tester.tap(predictTab.first);
      // Wait for layout and async Supabase live match fetch
      await tester.pumpAndSettle(const Duration(seconds: 3));
      debugPrint('Predict tab resolved.');
      
      // Ensure there are no error widgets. Our StateView handles errors. 
      // We can check that the screen rendered fully.
      final noOpenMatches = find.textContaining('No matches open for picks');
      final noFixturesImported = find.textContaining(
        'Upcoming fixtures will appear here once they are imported.',
      );
      
      if (noOpenMatches.evaluate().isNotEmpty ||
          noFixturesImported.evaluate().isNotEmpty) {
        debugPrint('Predict empty states are active (Expected if no fixtures are ready).');
      } else {
        debugPrint('Predict fixtures found and rendered.');
      }

      // Navigate to Hub
      debugPrint('Navigating to Hub Tab...');
      if (hubTab.evaluate().isNotEmpty) {
        await tester.tap(hubTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        debugPrint('Hub tab resolved.');
      }
    }
    
    debugPrint('Smoke test completed successfully — UI rendered without exceptions.');
  });
}
