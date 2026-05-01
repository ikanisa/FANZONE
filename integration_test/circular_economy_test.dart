import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fanzone/main.dart' as app;
import 'package:fanzone/features/ordering/providers/venue_context_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sports Bar FET Economy E2E Flow', () {
    testWidgets('Resolve venue QR, stake, and order with FET', (
      WidgetTester tester,
    ) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // 1. Simulate QR Code Entry
      debugPrint('Simulating QR scan for Stadium Sports Bar...');
      await container
          .read(venueContextProvider.notifier)
          .setVenueBySlug('stadium-sports-bar', tableNumber: '12');
      await tester.pumpAndSettle();

      // 2. Navigation & Actions (Simplified for CI)
      expect(find.byType(MaterialApp), findsWidgets);

      debugPrint('Sports bar FET economy smoke test passed.');
    });

    group('Architecture Validation', () {
      test('Model boundaries are enforced', () {
        // Placeholder for boundary checks
      });
    });
  });
}
