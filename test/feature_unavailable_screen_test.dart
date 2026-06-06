import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/features/settings/screens/feature_unavailable_screen.dart';

void main() {
  testWidgets('FeatureUnavailableScreen explains disabled routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bootstrapConfigProvider.overrideWithValue(_config())],
        child: const MaterialApp(
          home: FeatureUnavailableScreen(featureName: 'Archive'),
        ),
      ),
    );

    expect(find.text('Archive unavailable'), findsOneWidget);
    expect(find.text('UNAVAILABLE'), findsNothing);
    expect(find.textContaining('Archive'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('FeatureUnavailableScreen uses configured display labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bootstrapConfigProvider.overrideWithValue(_config())],
        child: const MaterialApp(
          home: FeatureUnavailableScreen(featureName: 'match_center'),
        ),
      ),
    );

    expect(find.text('Match Center unavailable'), findsOneWidget);
    expect(find.textContaining('match_center'), findsNothing);
  });

  testWidgets('FeatureUnavailableScreen sanitizes legacy rewards labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bootstrapConfigProvider.overrideWithValue(_config())],
        child: const MaterialApp(
          home: FeatureUnavailableScreen(featureName: 'wallet'),
        ),
      ),
    );

    expect(find.text('Rewards unavailable'), findsOneWidget);
    expect(find.textContaining('Wallet'), findsNothing);
  });
}

BootstrapConfig _config() {
  return BootstrapConfig(
    platformConfigVersion: 'cfg-feature-unavailable-test',
    platformFeatures: [
      PlatformFeatureInfo.fromJson({
        'feature_key': 'match_center',
        'display_name': 'Match Center',
        'status': 'disabled',
        'is_enabled': false,
        'channels': {
          'mobile': {
            'channel': 'mobile',
            'is_visible': false,
            'is_enabled': false,
            'show_in_navigation': false,
            'show_on_home': false,
            'sort_order': 20,
            'route_key': '/match/:matchId',
            'navigation_label': 'Match Center',
          },
        },
        'resolved_state': {
          'is_operational': false,
          'is_visible': false,
          'is_available': false,
          'show_in_navigation': false,
          'show_on_home': false,
          'route_key': '/match/:matchId',
          'sort_order': 20,
        },
      }),
      PlatformFeatureInfo.fromJson({
        'feature_key': 'wallet',
        'display_name': 'FET Wallet',
        'status': 'disabled',
        'is_enabled': false,
        'channels': {
          'mobile': {
            'channel': 'mobile',
            'is_visible': false,
            'is_enabled': false,
            'show_in_navigation': false,
            'show_on_home': false,
            'sort_order': 30,
            'route_key': '/wallet',
            'navigation_label': 'Wallet',
          },
        },
        'resolved_state': {
          'is_operational': false,
          'is_visible': false,
          'is_available': false,
          'show_in_navigation': false,
          'show_on_home': false,
          'route_key': '/wallet',
          'sort_order': 30,
        },
      }),
    ],
  );
}
