import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/widgets/common/fz_reference_modals.dart';

void main() {
  testWidgets('insufficient FET sheet uses rewards-ledger copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showFzInsufficientFetSheet(
                tester.element(find.byType(ElevatedButton)),
                requiredFet: 120,
                availableFet: 80,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Not enough FET'), findsOneWidget);
    expect(find.textContaining('available rewards'), findsOneWidget);
    expect(find.textContaining('available balance'), findsNothing);
    expect(find.text('Open Rewards'), findsOneWidget);
  });
}
