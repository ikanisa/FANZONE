import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/config/runtime_bootstrap.dart';
import 'package:fanzone/core/constants/phone_presets.dart';

BootstrapConfig _bootstrapConfig() {
  return BootstrapConfig(
    regions: const {
      'AA': RegionInfo(
        countryCode: 'AA',
        region: 'africa',
        countryName: 'Test Country',
        flagEmoji: '🏳️',
      ),
      'BB': RegionInfo(
        countryCode: 'BB',
        region: 'europe',
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
    phonePresets: const {
      'AA': PhonePresetInfo(
        dialCode: '+111',
        hint: '9XX XXX XXX',
        minDigits: 9,
      ),
      'BB': PhonePresetInfo(
        dialCode: '+222',
        hint: '8XXX XXX XXX',
        minDigits: 10,
      ),
      'CC': PhonePresetInfo(
        dialCode: '+333',
        hint: '777 123 4567',
        minDigits: 10,
      ),
    },
    currencyDisplay: const {},
    featureFlags: const {},
    appConfig: const {},
    launchMoments: const [],
  );
}

void main() {
  setUp(() {
    runtimeBootstrapStore.update(BootstrapConfig.empty());
  });

  group('PhonePreset', () {
    test('example combines dialCode and hint', () {
      const preset = PhonePreset(dialCode: '+111', hint: '9XX', minDigits: 9);
      expect(preset.example, '+111 9XX');
    });
  });

  group('phonePresetForCountry', () {
    test('returns null without bootstrap data', () {
      expect(phonePresetForCountry('AA'), isNull);
      expect(phonePresetForCountry(null), isNull);
      expect(phonePresetForCountry(''), isNull);
    });

    test('returns runtime bootstrap presets by country code', () {
      runtimeBootstrapStore.update(_bootstrapConfig());

      final alpha = phonePresetForCountry('AA');
      final beta = phonePresetForCountry('BB');
      final gamma = phonePresetForCountry('CC');

      expect(alpha, isNotNull);
      expect(alpha!.dialCode, '+111');
      expect(alpha.minDigits, 9);

      expect(beta, isNotNull);
      expect(beta!.dialCode, '+222');
      expect(beta.minDigits, 10);

      expect(gamma, isNotNull);
      expect(gamma!.dialCode, '+333');
      expect(gamma.minDigits, 10);
    });
  });

  group('phonePresetForRegion', () {
    test('returns neutral fallback without bootstrap data', () {
      final preset = phonePresetForRegion('africa');
      expect(preset.dialCode, '+');
      expect(preset.minDigits, 7);
    });

    test('selects region-backed presets from bootstrap data', () {
      runtimeBootstrapStore.update(_bootstrapConfig());

      expect(phonePresetForRegion('africa').dialCode, '+111');
      expect(phonePresetForRegion('europe').dialCode, '+222');
      expect(phonePresetForRegion('north_america').dialCode, '+333');
    });

    test('falls back to first available preset for unknown regions', () {
      runtimeBootstrapStore.update(_bootstrapConfig());

      final preset = phonePresetForRegion('unknown_region');
      expect(preset.dialCode, isNotEmpty);
      expect(preset.dialCode.startsWith('+'), true);
    });
  });
}
