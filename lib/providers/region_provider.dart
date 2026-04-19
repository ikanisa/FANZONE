import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/market/launch_market.dart';
import '../features/onboarding/providers/onboarding_service.dart';
import '../services/market_preferences_service.dart';

/// User region derived from explicit market preferences first, then teams.
///
/// Region only affects content priority and ordering. It never locks content.
enum UserRegion { africa, europe, northAmerica, global }

/// Provider that resolves the user's region from market preferences or teams.
final userRegionProvider = FutureProvider<UserRegion>((ref) async {
  final marketPreferences = await MarketPreferencesService.getUserPreferences();
  final preferredRegion = normalizeRegionKey(marketPreferences.primaryRegion);

  if (preferredRegion == 'africa') return UserRegion.africa;
  if (preferredRegion == 'europe') return UserRegion.europe;
  if (preferredRegion == 'north_america') return UserRegion.northAmerica;

  final cached = await OnboardingService.getCachedFavoriteTeams();
  if (cached.isEmpty) return UserRegion.global;

  // Priority: local team > first team with a country code
  final localTeam = cached.where((row) => row.source == 'local').firstOrNull;
  final primaryTeam = localTeam ?? cached.firstOrNull;
  final countryCode = primaryTeam?.teamCountryCode?.toUpperCase();

  if (countryCode == null || countryCode.isEmpty) return UserRegion.global;

  return regionFromCountryCode(countryCode);
});

/// Cached canonical region string for UI and query composition.
final userRegionStringProvider = Provider<String>((ref) {
  final region = ref.watch(userRegionProvider).valueOrNull ?? UserRegion.global;
  switch (region) {
    case UserRegion.africa:
      return 'africa';
    case UserRegion.europe:
      return 'europe';
    case UserRegion.northAmerica:
      return 'north_america';
    case UserRegion.global:
      return 'global';
  }
});

/// Region variants to use for backward-compatible Supabase filters.
final userRegionQueryValuesProvider = Provider<List<String>>((ref) {
  final region = ref.watch(userRegionStringProvider);
  return queryRegionVariants(region);
});

/// Map a 2-letter country code to a UserRegion.
UserRegion regionFromCountryCode(String code) {
  if (_africanCountryCodes.contains(code)) return UserRegion.africa;
  if (_northAmericanCountryCodes.contains(code)) return UserRegion.northAmerica;
  if (_europeanCountryCodes.contains(code)) return UserRegion.europe;
  return UserRegion.global;
}

const Set<String> _africanCountryCodes = {
  'RW',
  'NG',
  'KE',
  'ZA',
  'EG',
  'TZ',
  'UG',
  'GH',
  'TN',
  'DZ',
  'MA',
  'CD',
  'SN',
  'CI',
  'ML',
  'BF',
  'NE',
  'TG',
  'BJ',
  'GW',
  'ET',
  'CM',
  'AO',
  'MZ',
  'ZW',
  'ZM',
  'BW',
  'NA',
  'MW',
  'RG',
  'SL',
  'LR',
  'MG',
  'SD',
  'LY',
  'SO',
};

const Set<String> _northAmericanCountryCodes = {'US', 'CA', 'MX'};

const Set<String> _europeanCountryCodes = {
  'MT',
  'GB',
  'ES',
  'DE',
  'FR',
  'IT',
  'NL',
  'PT',
  'TR',
  'SE',
  'NO',
  'DK',
  'PL',
  'CH',
  'AT',
  'BE',
  'FI',
  'IE',
  'GR',
  'CZ',
  'HU',
  'RO',
  'BG',
  'HR',
  'RS',
  'SK',
  'SI',
  'UA',
  'RU',
  'IS',
  'CY',
  'LU',
  'EE',
  'LV',
  'LT',
};
