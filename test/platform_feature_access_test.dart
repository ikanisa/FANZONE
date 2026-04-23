import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/config/platform_feature_access.dart';

void main() {
  group('PlatformFeatureAccess', () {
    test(
      'uses registry visibility for channel-aware navigation and routes',
      () {
        final config = BootstrapConfig(
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

    test('falls back to legacy defaults when registry is unavailable', () {
      final config = BootstrapConfig.empty();
      final access = PlatformFeatureAccess(config, channel: 'mobile');

      expect(
        access.isVisible('fixtures', surface: PlatformSurface.navigation),
        isTrue,
      );
      expect(access.routeFor('wallet'), '/wallet');
      expect(
        access.navigationFeatures().map((item) => item.featureKey),
        containsAll(<String>[
          'home_feed',
          'fixtures',
          'predictions',
          'profile',
        ]),
      );
      expect(access.homeBlocks(), isNotEmpty);
    });
  });
}
