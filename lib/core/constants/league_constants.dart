/// League constants for the curated sports-bar football showcase.
///
/// Flag emojis are now backed by the `country_region_map` Supabase table
/// via [BootstrapConfig]. When bootstrap data is unavailable, callers fall
/// back to a neutral globe instead of country-specific static flags.
library;

import '../config/bootstrap_config.dart';
import '../config/runtime_bootstrap.dart';

const kRestOfWorldCompetitionRank = 1000;

const kPriorityCompetitionIds = <String>[
  'fifa-world-cup',
  'world-cup',
  'wc-2026',
  'champions-league',
  'uefa-champions-league',
  'europa-league',
  'uefa-europa-league',
  'epl',
  'la-liga',
  'serie-a',
  'ligue-1',
  'bundesliga',
];

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
  'England': '🏴',
  'Spain': '🇪🇸',
  'Italy': '🇮🇹',
  'Germany': '🇩🇪',
  'France': '🇫🇷',
};

/// Returns a flag emoji using DB-driven bootstrap config (by country name).
String flagForCountryDynamic(String? country, BootstrapConfig config) {
  if (country == null || country.isEmpty) return '🌍';
  final dbFlag = config.flagEmojiForCountryName(country);
  if (dbFlag != '🌍') return dbFlag;
  return '🌍';
}

/// Returns a flag emoji for a given country name, or a generic globe.
/// Uses runtime bootstrap config when available, otherwise a generic globe.
String flagForCountry(String? country) {
  if (country == null || country.isEmpty) return '🌍';
  final runtimeFlag = runtimeBootstrapStore.config.flagEmojiForCountryName(
    country,
  );
  if (runtimeFlag != '🌍') return runtimeFlag;
  return '🌍';
}

/// Whether the given country is one of the Top 5 European leagues.
bool isTop5Country(String? country) {
  if (country == null) return false;
  return kTop5EuropeanCountries.contains(country);
}

String _normalizeCompetitionKey(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int competitionCatalogRankByIdName(String? id, String? name) {
  final normalizedId = _normalizeCompetitionKey(id);
  final normalizedName = _normalizeCompetitionKey(name);

  final combined = '$normalizedId $normalizedName'.trim();

  if (combined.contains('fifa world cup') ||
      combined.contains('world cup') ||
      normalizedId == 'fifa world cup' ||
      normalizedId == 'world cup') {
    return 1;
  }

  if (combined.contains('champions league') ||
      normalizedId == 'ucl' ||
      normalizedId == 'uefa champions league') {
    return 2;
  }

  if (combined.contains('europa league') ||
      normalizedId == 'uel' ||
      normalizedId == 'uefa europa league') {
    return 3;
  }

  if (normalizedId == 'epl' ||
      normalizedName == 'premier league' ||
      normalizedName == 'english premier league') {
    return 10;
  }

  if (combined.contains('la liga')) {
    return 20;
  }

  if (combined.contains('serie a')) {
    return 30;
  }

  if (combined.contains('ligue 1')) {
    return 40;
  }

  if (combined.contains('bundesliga')) {
    return 50;
  }

  return kRestOfWorldCompetitionRank;
}

int competitionCatalogRank({String? id, String? name, int? catalogRank}) {
  if (catalogRank != null && catalogRank > 0) {
    return catalogRank;
  }
  return competitionCatalogRankByIdName(id, name);
}

bool isPriorityCompetitionByIdName(String? id, String? name) {
  return competitionCatalogRankByIdName(id, name) < kRestOfWorldCompetitionRank;
}
