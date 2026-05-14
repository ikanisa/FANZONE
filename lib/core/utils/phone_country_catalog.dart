import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:country_picker/country_picker.dart' as country_picker;

import '../config/bootstrap_config.dart';
import '../config/runtime_bootstrap.dart';
import '../constants/phone_presets.dart';

class PhoneCountryEntry {
  const PhoneCountryEntry({
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.preset,
  });

  final String countryCode;
  final String countryName;
  final String flagEmoji;
  final PhonePreset preset;

  String get dialDigits => preset.dialCode.replaceAll('+', '');
}

const _fallbackPhoneCountries = <PhoneCountryEntry>[
  PhoneCountryEntry(
    countryCode: 'MT',
    countryName: 'Malta',
    flagEmoji: '🇲🇹',
    preset: PhonePreset(dialCode: '+356', hint: '0000 0000', minDigits: 8),
  ),
  PhoneCountryEntry(
    countryCode: 'RW',
    countryName: 'Rwanda',
    flagEmoji: '🇷🇼',
    preset: PhonePreset(dialCode: '+250', hint: '000 000 000', minDigits: 9),
  ),
  PhoneCountryEntry(
    countryCode: 'GB',
    countryName: 'United Kingdom',
    flagEmoji: '🇬🇧',
    preset: PhonePreset(dialCode: '+44', hint: '0000 000000', minDigits: 10),
  ),
  PhoneCountryEntry(
    countryCode: 'US',
    countryName: 'United States',
    flagEmoji: '🇺🇸',
    preset: PhonePreset(dialCode: '+1', hint: '000 000 0000', minDigits: 10),
  ),
];

BootstrapConfig _resolvedConfig(BootstrapConfig? config) {
  return config ?? runtimeBootstrapStore.config;
}

List<String> _stringListConfigValue(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  return const <String>[];
}

String _flagEmojiForCountryCode(String countryCode, {String? fallback}) {
  if (fallback != null && fallback.isNotEmpty && fallback != '🌍') {
    return fallback;
  }
  if (countryCode.length != 2) return '🌍';
  final upper = countryCode.toUpperCase();
  final runes = upper.codeUnits.map((unit) => unit + 127397);
  return String.fromCharCodes(runes);
}

List<String> priorityPhoneCountryCodes({BootstrapConfig? config}) {
  final resolved = _resolvedConfig(config);
  final configured = _stringListConfigValue(
    resolved.appConfig['priority_phone_country_codes'],
  );
  final configuredDefault = resolved.appConfig['default_phone_country_code']
      ?.toString()
      .trim()
      .toUpperCase();
  final defaultCountry =
      configuredDefault != null && configuredDefault.isNotEmpty
      ? configuredDefault
      : 'MT';
  final localeCountry = PlatformDispatcher.instance.locale.countryCode
      ?.trim()
      .toUpperCase();

  return {
    defaultCountry,
    if (localeCountry != null && localeCountry.isNotEmpty) localeCountry,
    ...configured,
  }.toList(growable: false);
}

List<PhoneCountryEntry> phoneCountryCatalog({BootstrapConfig? config}) {
  final resolved = _resolvedConfig(config);
  final priorities = priorityPhoneCountryCodes(config: resolved);
  final entriesByCode = <String, PhoneCountryEntry>{};

  for (final country in country_picker.CountryService().getAll()) {
    final countryCode = country.countryCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) continue;
    entriesByCode[countryCode] = _entryFromPackageCountry(country, resolved);
  }

  for (final entry in _fallbackPhoneCountries) {
    entriesByCode.putIfAbsent(entry.countryCode, () => entry);
  }

  for (final override in resolved.phonePresets.entries) {
    final countryCode = override.key.trim().toUpperCase();
    if (countryCode.isEmpty) continue;
    final existing = entriesByCode[countryCode];
    entriesByCode[countryCode] = PhoneCountryEntry(
      countryCode: countryCode,
      countryName:
          resolved.countryNameForCode(countryCode) ??
          existing?.countryName ??
          countryCode,
      flagEmoji: _flagEmojiForCountryCode(
        countryCode,
        fallback: resolved.flagEmojiForCountryCode(countryCode),
      ),
      preset: PhonePreset.fromInfo(override.value),
    );
  }

  final entries = entriesByCode.values.toList(growable: false);

  entries.sort((left, right) {
    final leftPriority = priorities.indexOf(left.countryCode);
    final rightPriority = priorities.indexOf(right.countryCode);
    if (leftPriority != -1 || rightPriority != -1) {
      if (leftPriority == -1) return 1;
      if (rightPriority == -1) return -1;
      return leftPriority.compareTo(rightPriority);
    }
    return left.countryName.compareTo(right.countryName);
  });

  return entries;
}

PhoneCountryEntry _entryFromPackageCountry(
  country_picker.Country country,
  BootstrapConfig resolved,
) {
  final countryCode = country.countryCode.trim().toUpperCase();
  return PhoneCountryEntry(
    countryCode: countryCode,
    countryName: resolved.countryNameForCode(countryCode) ?? country.name,
    flagEmoji: _flagEmojiForCountryCode(
      countryCode,
      fallback: resolved.flagEmojiForCountryCode(countryCode),
    ),
    preset:
        phonePresetForCountryDynamic(countryCode, resolved) ??
        _phonePresetFromPackageCountry(country),
  );
}

PhonePreset _phonePresetFromPackageCountry(country_picker.Country country) {
  final dialDigits = country.phoneCode.replaceAll(RegExp(r'\D'), '');
  final exampleDigits = country.example.replaceAll(RegExp(r'\D'), '');
  final minDigits = exampleDigits.isEmpty
      ? 7
      : exampleDigits.length.clamp(5, 15).toInt();

  return PhonePreset(
    dialCode: dialDigits.isEmpty ? '+' : '+$dialDigits',
    hint: _phoneHintFromExample(country.example),
    minDigits: minDigits,
  );
}

String _phoneHintFromExample(String example) {
  final cleaned = example.trim();
  final digits = cleaned.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '000 000 000';

  final masked = cleaned.replaceAll(RegExp(r'\d'), '0');
  if (masked.contains(RegExp(r'[\s-]'))) {
    return masked.replaceAll('-', ' ');
  }

  return _groupedZeroHint(digits.length);
}

String _groupedZeroHint(int length) {
  if (length <= 4) return _zeros(length);
  if (length == 5) return '00 000';
  if (length == 6) return '000 000';
  if (length == 7) return '000 0000';
  if (length == 8) return '0000 0000';
  if (length == 9) return '000 000 000';
  if (length == 10) return '000 000 0000';
  if (length == 11) return '000 0000 0000';
  if (length == 12) return '0000 0000 0000';
  return '${_zeros(length - 8)} 0000 0000';
}

String _zeros(int count) => List.filled(math.max(0, count), '0').join();

PhoneCountryEntry preferredPhoneCountry({
  BootstrapConfig? config,
  String? explicitCountryCode,
}) {
  final catalog = phoneCountryCatalog(config: config);
  if (catalog.isEmpty) {
    return _fallbackPhoneCountries.first;
  }

  final resolved = _resolvedConfig(config);
  final requested = explicitCountryCode?.trim().toUpperCase();
  if (requested != null && requested.isNotEmpty) {
    for (final country in catalog) {
      if (country.countryCode == requested) return country;
    }
  }

  if (resolved.phonePresets.isEmpty) {
    return catalog.first;
  }

  final defaultCountry = resolved.appConfig['default_phone_country_code']
      ?.toString()
      .trim()
      .toUpperCase();
  if (defaultCountry != null && defaultCountry.isNotEmpty) {
    for (final country in catalog) {
      if (country.countryCode == defaultCountry) return country;
    }
  }

  final localeCountry = PlatformDispatcher.instance.locale.countryCode
      ?.trim()
      .toUpperCase();
  if (localeCountry != null && localeCountry.isNotEmpty) {
    for (final country in catalog) {
      if (country.countryCode == localeCountry) return country;
    }
  }

  return catalog.first;
}

PhoneCountryEntry findPhoneCountryByCode(
  String? code, {
  BootstrapConfig? config,
}) {
  return preferredPhoneCountry(config: config, explicitCountryCode: code);
}

PhoneCountryEntry resolvePhoneCountryFromPhoneInput(
  String value, {
  PhoneCountryEntry? fallback,
  BootstrapConfig? config,
}) {
  final base = fallback ?? preferredPhoneCountry(config: config);
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || !value.trimLeft().startsWith('+')) {
    return base;
  }

  final candidates = [...phoneCountryCatalog(config: config)]
    ..sort((a, b) => b.dialDigits.length.compareTo(a.dialDigits.length));
  for (final country in candidates) {
    if (country.dialDigits.isNotEmpty &&
        digits.startsWith(country.dialDigits)) {
      return country;
    }
  }
  return base;
}

int maxPhoneDigitsForHint(String hint, {int minDigits = 7}) {
  final groups = hint
      .split(RegExp(r'[^0-9Xx]+'))
      .where((group) => group.isNotEmpty)
      .map((group) => group.length)
      .toList(growable: false);
  if (groups.isEmpty) return math.max(minDigits, 12);
  final total = groups.fold<int>(0, (sum, group) => sum + group);
  return math.max(total, minDigits);
}

String formatPhoneDigits(String digits, String hint) {
  if (digits.isEmpty) return '';

  final groups = hint
      .split(RegExp(r'[^0-9Xx]+'))
      .where((group) => group.isNotEmpty)
      .map((group) => group.length)
      .toList(growable: false);
  if (groups.isEmpty) return digits;

  final parts = <String>[];
  var cursor = 0;
  for (final size in groups) {
    if (cursor >= digits.length) break;
    final end = math.min(cursor + size, digits.length);
    parts.add(digits.substring(cursor, end));
    cursor = end;
  }
  if (cursor < digits.length) {
    parts.add(digits.substring(cursor));
  }
  return parts.join(' ');
}

int phoneCountrySearchScore(PhoneCountryEntry country, String query) {
  final nameLower = country.countryName.toLowerCase();
  final codeLower = country.countryCode.toLowerCase();
  final dialCode = country.preset.dialCode;
  final dialDigits = country.dialDigits;

  if (codeLower == query) return 100;
  if (nameLower == query) return 95;
  if (dialCode == '+$query' || dialCode == query) return 90;
  if (dialDigits == query) return 90;

  var score = 0;

  if (nameLower.startsWith(query)) {
    score = math.max(score, 80);
  }

  if (codeLower.startsWith(query)) {
    score = math.max(score, 75);
  }

  if (dialCode.contains(query) || dialDigits.startsWith(query)) {
    score = math.max(score, 70);
  }

  if (score == 0) {
    final words = nameLower.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.startsWith(query)) {
        score = math.max(score, 65);
        break;
      }
    }
  }

  if (score == 0 && nameLower.contains(query)) {
    score = math.max(score, 50);
  }

  if (score == 0 && query.length >= 3) {
    var queryIndex = 0;
    for (
      var nameIndex = 0;
      nameIndex < nameLower.length && queryIndex < query.length;
      nameIndex++
    ) {
      if (nameLower[nameIndex] == query[queryIndex]) {
        queryIndex++;
      }
    }
    if (queryIndex == query.length) {
      score = math.max(score, 30);
    }
  }

  return score;
}
