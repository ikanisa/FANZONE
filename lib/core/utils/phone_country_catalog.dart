import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

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

const _genericPhonePreset = PhonePreset(
  dialCode: '+',
  hint: '000 000 000',
  minDigits: 7,
);

const _genericPhoneCountry = PhoneCountryEntry(
  countryCode: 'INTL',
  countryName: 'International',
  flagEmoji: '🌍',
  preset: _genericPhonePreset,
);

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
  final defaultCountry = resolved.appConfig['default_phone_country_code']
      ?.toString()
      .trim()
      .toUpperCase();
  final localeCountry = PlatformDispatcher.instance.locale.countryCode
      ?.trim()
      .toUpperCase();

  return {
    if (defaultCountry != null && defaultCountry.isNotEmpty) defaultCountry,
    if (localeCountry != null && localeCountry.isNotEmpty) localeCountry,
    ...configured,
  }.toList(growable: false);
}

List<PhoneCountryEntry> phoneCountryCatalog({BootstrapConfig? config}) {
  final resolved = _resolvedConfig(config);
  final availableCodes = resolved.phonePresets.keys
      .map((code) => code.toUpperCase())
      .toSet();

  if (availableCodes.isEmpty) {
    return const <PhoneCountryEntry>[_genericPhoneCountry];
  }

  final priorities = priorityPhoneCountryCodes(config: resolved);
  final entries = availableCodes
      .map((countryCode) {
        final preset =
            phonePresetForCountryDynamic(countryCode, resolved) ??
            _genericPhonePreset;
        return PhoneCountryEntry(
          countryCode: countryCode,
          countryName: resolved.countryNameForCode(countryCode) ?? countryCode,
          flagEmoji: _flagEmojiForCountryCode(
            countryCode,
            fallback: resolved.flagEmojiForCountryCode(countryCode),
          ),
          preset: preset,
        );
      })
      .toList(growable: false);

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

PhoneCountryEntry preferredPhoneCountry({
  BootstrapConfig? config,
  String? explicitCountryCode,
}) {
  final catalog = phoneCountryCatalog(config: config);
  if (catalog.isEmpty) {
    return _genericPhoneCountry;
  }

  final resolved = _resolvedConfig(config);
  final requested = explicitCountryCode?.trim().toUpperCase();
  if (requested != null && requested.isNotEmpty) {
    for (final country in catalog) {
      if (country.countryCode == requested) return country;
    }
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
