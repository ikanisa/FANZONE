/// League constants for the curated Top 5 European leagues showcase.
///
/// Flag emojis are now backed by the `country_region_map` Supabase table
/// via [BootstrapConfig].  The hardcoded [_defaultCountryFlags] map is
/// kept only as an offline fallback for first cold start.
library;

import '../config/bootstrap_config.dart';
import '../config/runtime_bootstrap.dart';

/// The Big 5 European domestic league countries — always shown first.
const kTop5EuropeanCountries = [
  'England',
  'Spain',
  'Italy',
  'Germany',
  'France',
];

/// Mapping of Top 5 countries to their canonical league short names.
const kTop5LeagueLabels = <String, String>{
  'England': 'EPL',
  'Spain': 'La Liga',
  'Italy': 'Serie A',
  'Germany': 'Bundesliga',
  'France': 'Ligue 1',
};

/// Country flag emojis for the Top 5.
const kTop5Flags = <String, String>{
  'England': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
  'Spain': '🇪🇸',
  'Italy': '🇮🇹',
  'Germany': '🇩🇪',
  'France': '🇫🇷',
};

/// Offline fallback country flag emojis for common countries.
/// New code should use [flagForCountryDynamic] with [BootstrapConfig].
const _defaultCountryFlags = <String, String>{
  'England': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
  'Spain': '🇪🇸',
  'Italy': '🇮🇹',
  'Germany': '🇩🇪',
  'France': '🇫🇷',
  'Rwanda': '🇷🇼',
  'Malta': '🇲🇹',
  'Egypt': '🇪🇬',
  'South Africa': '🇿🇦',
  'Nigeria': '🇳🇬',
  'Ghana': '🇬🇭',
  'Tunisia': '🇹🇳',
  'Morocco': '🇲🇦',
  'DR Congo': '🇨🇩',
  'Tanzania': '🇹🇿',
  'Senegal': '🇸🇳',
  'Cameroon': '🇨🇲',
  'Brazil': '🇧🇷',
  'Argentina': '🇦🇷',
  'Netherlands': '🇳🇱',
  'Belgium': '🇧🇪',
  'Portugal': '🇵🇹',
  'United States': '🇺🇸',
  'Mexico': '🇲🇽',
  'Japan': '🇯🇵',
  'South Korea': '🇰🇷',
  'Turkey': '🇹🇷',
  'Scotland': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
  'Kenya': '🇰🇪',
  'Uganda': '🇺🇬',
};

/// Returns a flag emoji using DB-driven bootstrap config (by country name).
/// Falls back to the hardcoded map if bootstrap config isn't loaded.
String flagForCountryDynamic(String? country, BootstrapConfig config) {
  if (country == null || country.isEmpty) return '🌍';
  // Try DB-driven config first (matches by country name)
  final dbFlag = config.flagEmojiForCountryName(country);
  if (dbFlag != '🌍') return dbFlag;
  // Fallback to hardcoded map
  return _defaultCountryFlags[country] ?? '🌍';
}

/// Returns a flag emoji for a given country name, or a generic globe.
/// Uses the hardcoded offline fallback only.
String flagForCountry(String? country) {
  if (country == null || country.isEmpty) return '🌍';
  final runtimeFlag = runtimeBootstrapStore.config.flagEmojiForCountryName(
    country,
  );
  if (runtimeFlag != '🌍') return runtimeFlag;
  return _defaultCountryFlags[country] ?? '🌍';
}

/// Whether the given country is one of the Top 5 European leagues.
bool isTop5Country(String? country) {
  if (country == null) return false;
  return kTop5EuropeanCountries.contains(country);
}
