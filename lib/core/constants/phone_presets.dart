/// Shared phone number presets by country/region.
///
/// Single source of truth for dial codes, hints, and minimum digit
/// requirements used in both the login and onboarding flows.
class PhonePreset {
  const PhonePreset({
    required this.dialCode,
    required this.hint,
    required this.minDigits,
  });

  /// International dial code (e.g. '+250').
  final String dialCode;

  /// Local-format hint displayed in the input field (e.g. '7XX XXX XXX').
  final String hint;

  /// Minimum number of digits expected (excluding dial code).
  final int minDigits;

  /// Full example string for display (e.g. '+250 7XX XXX XXX').
  String get example => '$dialCode $hint';
}

/// Resolve a [PhonePreset] from a two-letter ISO country code.
/// Returns `null` if the country code is not mapped.
PhonePreset? phonePresetForCountry(String? code) {
  switch (code) {
    case 'MT':
      return const PhonePreset(
        dialCode: '+356',
        hint: '79XX XXXX',
        minDigits: 8,
      );
    case 'RW':
      return const PhonePreset(
        dialCode: '+250',
        hint: '7XX XXX XXX',
        minDigits: 9,
      );
    case 'NG':
      return const PhonePreset(
        dialCode: '+234',
        hint: '80X XXX XXXX',
        minDigits: 10,
      );
    case 'KE':
      return const PhonePreset(
        dialCode: '+254',
        hint: '7XX XXX XXX',
        minDigits: 9,
      );
    case 'UG':
      return const PhonePreset(
        dialCode: '+256',
        hint: '7XX XXX XXX',
        minDigits: 9,
      );
    case 'GB':
      return const PhonePreset(
        dialCode: '+44',
        hint: '7XXX XXX XXX',
        minDigits: 10,
      );
    case 'DE':
      return const PhonePreset(
        dialCode: '+49',
        hint: '15XX XXX XXX',
        minDigits: 10,
      );
    case 'FR':
      return const PhonePreset(
        dialCode: '+33',
        hint: '6 XX XX XX XX',
        minDigits: 9,
      );
    case 'IT':
      return const PhonePreset(
        dialCode: '+39',
        hint: '3XX XXX XXXX',
        minDigits: 10,
      );
    case 'ES':
      return const PhonePreset(
        dialCode: '+34',
        hint: '6XX XXX XXX',
        minDigits: 9,
      );
    case 'PT':
      return const PhonePreset(
        dialCode: '+351',
        hint: '9XX XXX XXX',
        minDigits: 9,
      );
    case 'NL':
      return const PhonePreset(
        dialCode: '+31',
        hint: '6 XX XX XX XX',
        minDigits: 9,
      );
    case 'US':
    case 'CA':
      return const PhonePreset(
        dialCode: '+1',
        hint: '555 123 4567',
        minDigits: 10,
      );
    case 'MX':
      return const PhonePreset(
        dialCode: '+52',
        hint: '55 1234 5678',
        minDigits: 10,
      );
    default:
      return null;
  }
}

/// Default presets per region (used when device locale is not mapped).
PhonePreset phonePresetForRegion(String normalizedRegionKey) {
  switch (normalizedRegionKey) {
    case 'africa':
      return const PhonePreset(
        dialCode: '+250',
        hint: '7XX XXX XXX',
        minDigits: 9,
      );
    case 'europe':
      return const PhonePreset(
        dialCode: '+44',
        hint: '7XXX XXX XXX',
        minDigits: 10,
      );
    case 'north_america':
    default:
      return const PhonePreset(
        dialCode: '+1',
        hint: '555 123 4567',
        minDigits: 10,
      );
  }
}
