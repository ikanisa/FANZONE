import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/constants/phone_presets.dart';

void main() {
  group('PhonePreset', () {
    test('example combines dialCode and hint', () {
      const preset = PhonePreset(dialCode: '+250', hint: '7XX', minDigits: 9);
      expect(preset.example, '+250 7XX');
    });
  });

  group('phonePresetForCountry', () {
    test('returns correct preset for MT', () {
      final preset = phonePresetForCountry('MT');
      expect(preset, isNotNull);
      expect(preset!.dialCode, '+356');
      expect(preset.minDigits, 8);
    });

    test('returns correct preset for RW', () {
      final preset = phonePresetForCountry('RW');
      expect(preset, isNotNull);
      expect(preset!.dialCode, '+250');
      expect(preset.minDigits, 9);
    });

    test('returns correct preset for NG', () {
      final preset = phonePresetForCountry('NG');
      expect(preset, isNotNull);
      expect(preset!.dialCode, '+234');
      expect(preset.minDigits, 10);
    });

    test('returns correct preset for KE', () {
      final preset = phonePresetForCountry('KE');
      expect(preset, isNotNull);
      expect(preset!.dialCode, '+254');
      expect(preset.minDigits, 9);
    });

    test('returns correct preset for GB', () {
      final preset = phonePresetForCountry('GB');
      expect(preset, isNotNull);
      expect(preset!.dialCode, '+44');
      expect(preset.minDigits, 10);
    });

    test('US and CA share the same dial code', () {
      final us = phonePresetForCountry('US');
      final ca = phonePresetForCountry('CA');
      expect(us, isNotNull);
      expect(ca, isNotNull);
      expect(us!.dialCode, ca!.dialCode);
      expect(us.dialCode, '+1');
      expect(us.minDigits, 10);
    });

    test('returns null for unmapped country', () {
      expect(phonePresetForCountry('ZZ'), isNull);
      expect(phonePresetForCountry(null), isNull);
      expect(phonePresetForCountry(''), isNull);
    });

    test('all mapped countries return non-null with valid dial codes', () {
      const countries = ['MT', 'RW', 'NG', 'KE', 'UG', 'GB', 'DE', 'FR', 'IT', 'ES', 'PT', 'NL', 'US', 'CA', 'MX'];
      for (final code in countries) {
        final preset = phonePresetForCountry(code);
        expect(preset, isNotNull, reason: '$code should have a preset');
        expect(preset!.dialCode.startsWith('+'), isTrue, reason: '$code dial code should start with +');
        expect(preset.minDigits, greaterThanOrEqualTo(8), reason: '$code minDigits should be >= 8');
        expect(preset.hint.isNotEmpty, isTrue, reason: '$code hint should not be empty');
      }
    });
  });

  group('phonePresetForRegion', () {
    test('africa defaults to +250', () {
      final preset = phonePresetForRegion('africa');
      expect(preset.dialCode, '+250');
      expect(preset.minDigits, 9);
    });

    test('europe defaults to +44', () {
      final preset = phonePresetForRegion('europe');
      expect(preset.dialCode, '+44');
      expect(preset.minDigits, 10);
    });

    test('north_america defaults to +1', () {
      final preset = phonePresetForRegion('north_america');
      expect(preset.dialCode, '+1');
      expect(preset.minDigits, 10);
    });

    test('unknown region falls through to +1 default', () {
      final preset = phonePresetForRegion('unknown_region');
      expect(preset.dialCode, '+1');
    });
  });
}
