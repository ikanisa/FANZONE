import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/app_router.dart';
import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/config/runtime_bootstrap.dart';

void main() {
  group('governedAppRouteForPath', () {
    setUp(() {
      runtimeBootstrapStore.update(
        BootstrapConfig(
          platformConfigVersion: 'cfg-router-test',
          platformFeatures: [
            PlatformFeatureInfo.fromJson({
              'feature_key': 'pools',
              'display_name': 'Pools',
              'status': 'active',
              'is_enabled': true,
              'default_route_key': '/pools',
              'channels': {
                'mobile': {
                  'channel': 'mobile',
                  'is_visible': true,
                  'is_enabled': true,
                  'show_in_navigation': true,
                  'show_on_home': true,
                  'sort_order': 10,
                  'route_key': '/pools',
                  'navigation_label': 'Pools',
                },
                'web': {
                  'channel': 'web',
                  'is_visible': true,
                  'is_enabled': true,
                  'show_in_navigation': false,
                  'show_on_home': false,
                  'sort_order': 10,
                  'route_key': '/fixtures',
                },
              },
              'resolved_state': {
                'is_operational': true,
                'is_visible': true,
                'is_available': true,
                'show_in_navigation': true,
                'show_on_home': true,
                'route_key': '/pools',
                'sort_order': 10,
              },
            }),
            PlatformFeatureInfo.fromJson({
              'feature_key': 'wallet',
              'display_name': 'Wallet',
              'status': 'active',
              'is_enabled': true,
              'default_route_key': '/wallet',
              'channels': {
                'mobile': {
                  'channel': 'mobile',
                  'is_visible': true,
                  'is_enabled': true,
                  'show_in_navigation': false,
                  'show_on_home': false,
                  'sort_order': 20,
                  'route_key': '/wallet',
                  'navigation_label': 'Wallet',
                },
                'web': {
                  'channel': 'web',
                  'is_visible': true,
                  'is_enabled': true,
                  'show_in_navigation': true,
                  'show_on_home': false,
                  'sort_order': 20,
                  'route_key': '/wallet',
                },
              },
              'resolved_state': {
                'is_operational': true,
                'is_visible': true,
                'is_available': true,
                'show_in_navigation': false,
                'show_on_home': false,
                'route_key': '/wallet',
                'sort_order': 20,
              },
            }),
            PlatformFeatureInfo.fromJson({
              'feature_key': 'match_center',
              'display_name': 'Match Center',
              'status': 'active',
              'is_enabled': true,
              'default_route_key': '/match/:matchId',
              'channels': {
                'mobile': {
                  'channel': 'mobile',
                  'is_visible': true,
                  'is_enabled': true,
                  'show_in_navigation': false,
                  'show_on_home': false,
                  'sort_order': 30,
                  'route_key': '/match/:matchId',
                  'navigation_label': 'Match Center',
                },
                'web': {
                  'channel': 'web',
                  'is_visible': true,
                  'is_enabled': true,
                  'show_in_navigation': false,
                  'show_on_home': false,
                  'sort_order': 30,
                  'route_key': '/match/:matchId',
                },
              },
              'resolved_state': {
                'is_operational': true,
                'is_visible': true,
                'is_available': true,
                'show_in_navigation': false,
                'show_on_home': false,
                'route_key': '/match/:matchId',
                'sort_order': 30,
              },
            }),
          ],
        ),
      );
    });

    tearDown(() {
      runtimeBootstrapStore.update(BootstrapConfig.empty());
    });

    test('normalizes hosted deep links into in-app routes', () {
      expect(
        governedAppRouteForPath(
          'https://fanzone.ikanisa.com/pools?source=push',
        ),
        '/pools?source=push',
      );
      expect(
        governedAppRouteForPath(
          'https://fanzone.ikanisa.com/match/match_42?entry=notification',
        ),
        '/match/match_42?entry=notification',
      );
    });

    test('preserves relative in-app locations and falls back safely', () {
      expect(
        governedAppRouteForPath('/wallet?tab=history'),
        '/wallet?tab=history',
      );
      expect(governedAppRouteForPath('', fallback: '/fixtures'), '/fixtures');
    });
  });
}
