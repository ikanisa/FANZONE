/// League constants for the curated Top 5 European leagues showcase.
///
/// These define the five premier European domestic leagues that are always
/// displayed prominently in the Leagues Discovery screen.
library;

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

/// Country flag emojis for common non-Top-5 countries.
const kCountryFlags = <String, String>{
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

/// Returns a flag emoji for a given country name, or a generic globe.
String flagForCountry(String? country) {
  if (country == null || country.isEmpty) return '🌍';
  return kCountryFlags[country] ?? '🌍';
}

/// Whether the given country is one of the Top 5 European leagues.
bool isTop5Country(String? country) {
  if (country == null) return false;
  return kTop5EuropeanCountries.contains(country);
}
