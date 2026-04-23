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
          featureFlags: const {},
          appConfig: const {},
          launchMoments: const [],
        ),
      );

      expect(regionFromCountryName('Test Country'), 'europe');
      expect(regionFromCountryName('Country Beta'), 'africa');
      expect(regionFromCountryName('Country Gamma'), 'north_america');
      expect(regionFromCountryName('Country Delta'), isNull);
    });

    test('returns sensible default focus tags per region', () {
      expect(
        defaultFocusTagsForRegion('africa'),
        contains('africa-fan-momentum-2026'),
      );
      expect(defaultFocusTagsForRegion('europe'), contains('ucl-final-2026'));
      expect(
        defaultFocusTagsForRegion('north_america'),
        contains('worldcup2026'),
      );
    });
  });
}
