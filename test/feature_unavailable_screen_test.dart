import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/settings/screens/feature_unavailable_screen.dart';

void main() {
  testWidgets('FeatureUnavailableScreen explains disabled routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FeatureUnavailableScreen(featureName: 'Archive')),
    );

    expect(find.text('Archive IS NOT LIVE'), findsOneWidget);
    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.textContaining('Archive'), findsOneWidget);
  });
}
