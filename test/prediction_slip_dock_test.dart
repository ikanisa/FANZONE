import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/providers/prediction_slip_provider.dart';
import 'package:fanzone/widgets/predict/prediction_slip_dock.dart';

import 'support/test_fixtures.dart';

void main() {
  testWidgets('prediction slip dock renders safely inside SafeArea', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SafeArea(child: PredictionSlipDock())),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SafeArea)),
    );
    container
        .read(predictionSlipProvider.notifier)
        .toggleMatchResult(sampleMatch(), '1', multiplier: 1.7);

    await tester.pump();

    expect(find.text('Free Prediction Slip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
