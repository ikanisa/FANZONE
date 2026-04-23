/// Shared phone number presets.
///
/// Presets are sourced from Supabase bootstrap tables via [BootstrapConfig].
/// When bootstrap data is unavailable, the app falls back to a neutral
/// international placeholder instead of market-specific hardcoded rules.
library;

import '../config/bootstrap_config.dart';
import '../config/runtime_bootstrap.dart';

class PhonePreset {
  const PhonePreset({
    required this.dialCode,
    required this.hint,
    required this.minDigits,
  });

  factory PhonePreset.fromInfo(PhonePresetInfo info) {
    return PhonePreset(
      dialCode: info.dialCode,
      hint: info.hint,
      minDigits: info.minDigits,
    );
  }

  final String dialCode;
  final String hint;
  final int minDigits;

  String get example => '$dialCode $hint';
}

const _genericPhonePreset = PhonePreset(
  dialCode: '+',
  hint: '000 000 000',
  minDigits: 7,
);

PhonePreset? phonePresetForCountryDynamic(
  String? code,
  BootstrapConfig config,
) {
  if (code == null || code.isEmpty) return null;
  final info = config.phonePresetForCountry(code);
  if (info == null) return null;
  return PhonePreset.fromInfo(info);
}

PhonePreset? phonePresetForCountry(String? code) {
  if (code == null || code.isEmpty) return null;
  final info = runtimeBootstrapStore.config.phonePresetForCountry(code);
  if (info == null) return null;
  return PhonePreset.fromInfo(info);
}

PhonePreset phonePresetForRegionDynamic(
  String normalizedRegionKey,
  BootstrapConfig config,
) {
  return PhonePreset.fromInfo(config.phonePresetForRegion(normalizedRegionKey));
}

PhonePreset phonePresetForRegion(String normalizedRegionKey) {
  final runtimeConfig = runtimeBootstrapStore.config;
  if (runtimeConfig.phonePresets.isNotEmpty) {
    return PhonePreset.fromInfo(
      runtimeConfig.phonePresetForRegion(normalizedRegionKey),
    );
  }
  return _genericPhonePreset;
}
