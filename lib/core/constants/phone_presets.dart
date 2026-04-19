/// Shared phone number presets by country/region.
///
/// Phone presets are now backed by the `phone_presets` Supabase table
/// via [BootstrapConfig].  The hardcoded switch statement is kept only
/// as an offline fallback for first cold start.
library;

import '../config/bootstrap_config.dart';
import '../config/runtime_bootstrap.dart';

class PhonePreset {
  const PhonePreset({
    required this.dialCode,
    required this.hint,
    required this.minDigits,
  });

  /// Create from DB-driven [PhonePresetInfo].
  factory PhonePreset.fromInfo(PhonePresetInfo info) {
    return PhonePreset(
      dialCode: info.dialCode,
      hint: info.hint,
      minDigits: info.minDigits,
    );
  }

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
///
/// Tries DB-driven [BootstrapConfig] first, falls back to hardcoded defaults.
PhonePreset? phonePresetForCountryDynamic(
  String? code,
  BootstrapConfig config,
) {
  if (code == null || code.isEmpty) return null;
  final info = config.phonePresetForCountry(code);
  if (info != null) return PhonePreset.fromInfo(info);
  // Fallback to hardcoded presets
  return _hardcodedPresetForCountry(code);
}

/// Resolve a [PhonePreset] from a two-letter ISO country code (offline).
/// Returns `null` if the country code is not mapped.
PhonePreset? phonePresetForCountry(String? code) {
  final info = runtimeBootstrapStore.config.phonePresetForCountry(code);
  if (info != null) return PhonePreset.fromInfo(info);
  return _hardcodedPresetForCountry(code);
}

/// Default presets per region — tries DB-driven config first.
PhonePreset phonePresetForRegionDynamic(
  String normalizedRegionKey,
  BootstrapConfig config,
) {
  final info = config.phonePresetForRegion(normalizedRegionKey);
  return PhonePreset.fromInfo(info);
}

/// Default presets per region (used when device locale is not mapped).
PhonePreset phonePresetForRegion(String normalizedRegionKey) {
  final runtimeConfig = runtimeBootstrapStore.config;
  if (runtimeConfig.phonePresets.isNotEmpty) {
    return PhonePreset.fromInfo(
      runtimeConfig.phonePresetForRegion(normalizedRegionKey),
    );
  }

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

PhonePreset? _hardcodedPresetForCountry(String? code) {
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
