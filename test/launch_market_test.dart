import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/market/launch_market.dart';

void main() {
  group('launch market helpers', () {
    test('normalizes North America aliases', () {
      expect(normalizeRegionKey('americas'), 'north_america');
      expect(normalizeRegionKey('north-america'), 'north_america');
      expect(normalizeRegionKey('North America'), 'north_america');
    });

    test('maps country names to rollout regions', () {
      expect(regionFromCountryName('Malta'), 'europe');
      expect(regionFromCountryName('Nigeria'), 'africa');
      expect(regionFromCountryName('Canada'), 'north_america');
      expect(regionFromCountryName('Brazil'), isNull);
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
