import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/features/predict/widgets/prediction_entry_sheet.dart';
import 'package:fanzone/models/prediction_engine_output_model.dart';

import 'support/test_app.dart';
import 'support/test_fixtures.dart';

void main() {
  testWidgets('prediction entry sheet renders lean pick controls', (
    tester,
  ) async {
    final match = sampleMatch();

    await pumpAppScreen(
      tester,
      Scaffold(
        body: PredictionEntrySheet(
          match: match,
          engineOutput: PredictionEngineOutputModel(
            id: 'engine_1',
            matchId: match.id,
            modelVersion: 'simple_form_v1',
            homeWinScore: 0.52,
            drawScore: 0.25,
            awayWinScore: 0.23,
            over25Score: 0.60,
            bttsScore: 0.55,
            predictedHomeGoals: 2,
            predictedAwayGoals: 1,
            confidenceLabel: 'medium',
            generatedAt: DateTime(2026, 4, 19, 12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Pick'), findsOneWidget);
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text('Over 2.5 goals'), findsOneWidget);
    expect(find.text('Both teams to score'), findsOneWidget);
    expect(find.text('SCORELINE'), findsOneWidget);
    expect(find.text('Save prediction'), findsOneWidget);
  });
}
