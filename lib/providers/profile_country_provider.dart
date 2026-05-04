import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';

const supportedProfileCountryCodes = ['MT', 'RW'];

class ProfileCountryController extends StateNotifier<String> {
  ProfileCountryController(this._ref) : super(_initialCountryCode(_ref));

  static const _storageKey = 'profile_country_code';

  final Ref _ref;

  void setCountryCode(String countryCode) {
    final normalized = countryCode.trim().toUpperCase();
    if (!supportedProfileCountryCodes.contains(normalized)) return;
    if (state == normalized) return;
    state = normalized;
    _ref.read(sharedPreferencesProvider).setString(_storageKey, normalized);
  }

  static String _initialCountryCode(Ref ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    final cached =
        prefs.getString(_storageKey)?.trim().toUpperCase() ??
        prefs.getString('venue_market_country_code')?.trim().toUpperCase();
    if (cached != null && supportedProfileCountryCodes.contains(cached)) {
      return cached;
    }

    final localeCountry = PlatformDispatcher.instance.locale.countryCode
        ?.trim()
        .toUpperCase();
    if (localeCountry != null &&
        supportedProfileCountryCodes.contains(localeCountry)) {
      return localeCountry;
    }

    return 'MT';
  }
}

final profileCountryProvider =
    StateNotifierProvider<ProfileCountryController, String>((ref) {
      return ProfileCountryController(ref);
    });
