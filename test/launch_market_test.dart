import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/config/runtime_bootstrap.dart';
import 'package:fanzone/core/market/launch_market.dart';

void main() {
  setUp(() {
    runtimeBootstrapStore.update(BootstrapConfig.empty());
  });

  group('launch market helpers', () {
    test('normalizes North America aliases', () {
      expect(normalizeRegionKey('americas'), 'north_america');
      expect(normalizeRegionKey('north-america'), 'north_america');
      expect(normalizeRegionKey('North America'), 'north_america');
    });

    test('maps country names to rollout regions from bootstrap config', () {
      runtimeBootstrapStore.update(
        BootstrapConfig(
          regions: const {
            'AA': RegionInfo(
              countryCode: 'AA',
              region: 'europe',
              countryName: 'Test Country',
              flagEmoji: '🏳️',
            ),
            'BB': RegionInfo(
              countryCode: 'BB',
              region: 'africa',
              countryName: 'Country Beta',
              flagEmoji: '🏴',
            ),
            'CC': RegionInfo(
              countryCode: 'CC',
              region: 'north_america',
              countryName: 'Country Gamma',
              flagEmoji: '🏁',
            ),
          },
          phonePresets: const {},
          currencyDisplay: const {},
          countryCurrencies: const {},
          featureFlags: const {},
          appConfig: const {},
          launchMoments: const [
            LaunchMomentInfo(
              tag: 'global-focus',
              title: 'Global Focus',
              subtitle: 'Global launch moment',
              kicker: 'Global',
              regionKey: 'global',
            ),
            LaunchMomentInfo(
              tag: 'africa-focus',
              title: 'Africa Focus',
              subtitle: 'Africa launch moment',
              kicker: 'Africa',
              regionKey: 'africa',
            ),
            LaunchMomentInfo(
              tag: 'europe-focus',
              title: 'Europe Focus',
              subtitle: 'Europe launch moment',
              kicker: 'Europe',
              regionKey: 'europe',
            ),
            LaunchMomentInfo(
              tag: 'na-focus',
              title: 'North America Focus',
              subtitle: 'North America launch moment',
              kicker: 'North America',
              regionKey: 'north_america',
            ),
          ],
        ),
      );

      expect(regionFromCountryName('Test Country'), 'europe');
      expect(regionFromCountryName('Country Beta'), 'africa');
      expect(regionFromCountryName('Country Gamma'), 'north_america');
      expect(regionFromCountryName('Country Delta'), isNull);
    });

    test('derives focus tags from runtime launch moments only', () {
      runtimeBootstrapStore.update(
        BootstrapConfig(
          regions: const {},
          phonePresets: const {},
          currencyDisplay: const {},
          countryCurrencies: const {},
          featureFlags: const {},
          appConfig: const {},
          launchMoments: const [
            LaunchMomentInfo(
              tag: 'global-focus',
              title: 'Global Focus',
              subtitle: 'Global launch moment',
              kicker: 'Global',
              regionKey: 'global',
            ),
            LaunchMomentInfo(
              tag: 'africa-focus',
              title: 'Africa Focus',
              subtitle: 'Africa launch moment',
              kicker: 'Africa',
              regionKey: 'africa',
            ),
            LaunchMomentInfo(
              tag: 'europe-focus',
              title: 'Europe Focus',
              subtitle: 'Europe launch moment',
              kicker: 'Europe',
              regionKey: 'europe',
            ),
            LaunchMomentInfo(
              tag: 'na-focus',
              title: 'North America Focus',
              subtitle: 'North America launch moment',
              kicker: 'North America',
              regionKey: 'north_america',
            ),
          ],
        ),
      );

      expect(defaultFocusTagsForRegion('africa'), [
        'global-focus',
        'africa-focus',
      ]);
      expect(defaultFocusTagsForRegion('europe'), [
        'global-focus',
        'europe-focus',
      ]);
      expect(defaultFocusTagsForRegion('north_america'), [
        'global-focus',
        'na-focus',
      ]);
    });
  });
}
