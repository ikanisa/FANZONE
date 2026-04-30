import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/config/platform_feature_access.dart';

void main() {
  group('PlatformFeatureAccess', () {
    test(
      'uses registry visibility for channel-aware navigation and routes',
      () {
        final config = BootstrapConfig(
          platformConfigVersion: 'cfg-v0',
          regions: const {},
          phonePresets: const {},
          currencyDisplay: const {},
          countryCurrencies: const {},
          featureFlags: const {'predictions': true, 'wallet': true},
          appConfig: const {},
          launchMoments: const [],
          platformFeatures: [
            PlatformFeatureInfo.fromJson({
              'feature_key': 'predictions',
              'display_name': 'Predictions',
              'status': 'active',
              'is_enabled': true,
              'channels': {
                'mobile': {
                  'channel': 'mobile',
                  'is_visible': true,
                  'is_enabled': true,
                  'show_in_navigation': true,
                  'show_on_home': true,
                  'sort_order': 20,
                  'route_key': '/predict',
                  'navigation_label': 'Predict',
                },
                'web': {
                  'channel': 'web',
                  'is_visible': false,
                  'is_enabled': false,
                  'show_in_navigation': false,
                  'show_on_home': false,
                  'sort_order': 20,
                  'route_key': '/predict',
                },
              },
              'resolved_state': {
                'is_operational': true,
                'is_visible': true,
                'is_available': true,
                'show_in_navigation': true,
                'show_on_home': true,
                'route_key': '/predict',
                'sort_order': 20,
              },
            }),
          ],
          platformContentBlocks: [
            PlatformContentBlockInfo.fromJson({
              'block_key': 'home_promo_banner',
              'block_type': 'promo_banner',
              'title': 'Lean Matchday Window',
              'content': {'cta_route': '/predict'},
              'target_channel': 'mobile',
              'is_active': true,
              'sort_order': 10,
              'feature_key': 'predictions',
              'placement_key': 'home.primary',
            }),
          ],
        );

        final access = PlatformFeatureAccess(config, channel: 'mobile');

        expect(
          access.isVisible('predictions', surface: PlatformSurface.navigation),
          isTrue,
        );
        expect(access.routeFor('predictions'), '/predict');
        expect(
          access.navigationFeatures().map((item) => item.featureKey),
          contains('predictions'),
        );
        expect(
          access.homeBlocks().map((block) => block.blockKey),
          contains('home_promo_banner'),
        );
      },
    );

    test(
      'does not fabricate mobile defaults when the registry is unavailable',
      () {
        final config = BootstrapConfig.empty();
        final access = PlatformFeatureAccess(config, channel: 'mobile');

        expect(
          access.isVisible('fixtures', surface: PlatformSurface.navigation),
          isFalse,
        );
        expect(access.routeFor('wallet'), '/');
        expect(access.navigationFeatures(), isEmpty);
        expect(access.homeBlocks(), isEmpty);
      },
    );

    test('missing registry features are unavailable for guarded actions', () {
      final access = PlatformFeatureAccess(
        BootstrapConfig.empty(),
        channel: 'mobile',
      );

      expect(
        access.isActionAvailable('wallet', isAuthenticated: false),
        isFalse,
      );
      expect(
        access.isActionAvailable('wallet', isAuthenticated: true),
        isFalse,
      );
      expect(
        access.isActionAvailable('predictions', isAuthenticated: false),
        isFalse,
      );
    });

    test('home blocks respect resolved feature visibility and ordering', () {
      final config = BootstrapConfig(
        platformConfigVersion: 'cfg-v1',
        regions: const {},
        phonePresets: const {},
        currencyDisplay: const {},
        countryCurrencies: const {},
        featureFlags: const {},
        appConfig: const {},
        launchMoments: const [],
        platformFeatures: [
          PlatformFeatureInfo.fromJson({
            'feature_key': 'predictions',
            'display_name': 'Predictions',
            'status': 'active',
            'is_enabled': true,
            'channels': {
              'mobile': {
                'channel': 'mobile',
                'is_visible': true,
                'is_enabled': true,
                'show_in_navigation': true,
                'show_on_home': false,
                'sort_order': 30,
                'route_key': '/predict',
                'navigation_label': 'Predict',
              },
              'web': {
                'channel': 'web',
                'is_visible': true,
                'is_enabled': true,
                'show_in_navigation': false,
                'show_on_home': false,
                'sort_order': 30,
                'route_key': '/fixtures',
              },
            },
            'resolved_state': {
              'is_operational': true,
              'is_visible': true,
              'is_available': true,
              'show_in_navigation': true,
              'show_on_home': false,
              'route_key': '/predict',
              'sort_order': 30,
            },
          }),
          PlatformFeatureInfo.fromJson({
            'feature_key': 'fixtures',
            'display_name': 'Fixtures',
            'status': 'active',
            'is_enabled': true,
            'channels': {
              'mobile': {
                'channel': 'mobile',
                'is_visible': true,
                'is_enabled': true,
                'show_in_navigation': true,
                'show_on_home': true,
                'sort_order': 20,
                'route_key': '/fixtures',
                'navigation_label': 'Fixtures',
              },
              'web': {
                'channel': 'web',
                'is_visible': true,
                'is_enabled': true,
                'show_in_navigation': true,
                'show_on_home': true,
                'sort_order': 20,
                'route_key': '/fixtures',
              },
            },
            'resolved_state': {
              'is_operational': true,
              'is_visible': true,
              'is_available': true,
              'show_in_navigation': true,
              'show_on_home': true,
              'route_key': '/fixtures',
              'sort_order': 20,
            },
          }),
        ],
        platformContentBlocks: [
          PlatformContentBlockInfo.fromJson({
            'block_key': 'hidden_prediction_banner',
            'block_type': 'promo_banner',
            'title': 'Prediction Push',
            'content': {'cta_route': '/predict'},
            'target_channel': 'mobile',
            'is_active': true,
            'sort_order': 10,
            'feature_key': 'predictions',
            'placement_key': 'home.primary',
          }),
          PlatformContentBlockInfo.fromJson({
            'block_key': 'fixtures_live_matches',
            'block_type': 'live_matches',
            'title': 'Live Now',
            'content': const {},
            'target_channel': 'mobile',
            'is_active': true,
            'sort_order': 20,
            'feature_key': 'fixtures',
            'placement_key': 'home.primary',
          }),
        ],
      );

      final access = PlatformFeatureAccess(config, channel: 'mobile');

      expect(
        access.homeBlocks().map((block) => block.blockKey),
        equals(<String>['fixtures_live_matches']),
      );
    });
  });
}
