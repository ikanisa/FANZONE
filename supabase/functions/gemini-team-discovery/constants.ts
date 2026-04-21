export const FUNCTION_NAME = "gemini-team-discovery";

export const DEFAULT_GEMINI_MODEL = (() => {
  try {
    return Deno.env.get("TEAM_DISCOVERY_MODEL")?.trim() || "gemini-2.0-flash";
  } catch {
    return "gemini-2.0-flash";
  }
})();

export const ALLOWED_HEADERS =
  "authorization, x-client-info, apikey, content-type, x-match-sync-secret";

/**
 * Master league catalog: country_code → { country, league, teams_expected }
 * First division / Premier League ONLY for each country.
 * ~100+ countries across Europe, Africa, and the Americas.
 */
export interface LeagueEntry {
  country: string;
  countryCode: string;
  league: string | null;
  region: "europe" | "africa" | "americas";
  expectedTeams: number;
}

export const LEAGUE_CATALOG: LeagueEntry[] = [
  // ═══════════════════════════════════════════════════════════
  // EUROPE (~45 countries)
  // ═══════════════════════════════════════════════════════════
  { country: "England", countryCode: "GB", league: "Premier League", region: "europe", expectedTeams: 20 },
  { country: "Scotland", countryCode: "XS", league: "Scottish Premiership", region: "europe", expectedTeams: 12 },
  { country: "Wales", countryCode: "XW", league: "Cymru Premier", region: "europe", expectedTeams: 12 },
  { country: "Northern Ireland", countryCode: "XI", league: "NIFL Premiership", region: "europe", expectedTeams: 12 },
  { country: "Spain", countryCode: "ES", league: "La Liga", region: "europe", expectedTeams: 20 },
  { country: "Germany", countryCode: "DE", league: "Bundesliga", region: "europe", expectedTeams: 18 },
  { country: "France", countryCode: "FR", league: "Ligue 1", region: "europe", expectedTeams: 18 },
  { country: "Italy", countryCode: "IT", league: "Serie A", region: "europe", expectedTeams: 20 },
  { country: "Portugal", countryCode: "PT", league: "Primeira Liga", region: "europe", expectedTeams: 18 },
  { country: "Netherlands", countryCode: "NL", league: "Eredivisie", region: "europe", expectedTeams: 18 },
  { country: "Belgium", countryCode: "BE", league: "Pro League", region: "europe", expectedTeams: 16 },
  { country: "Turkey", countryCode: "TR", league: "Süper Lig", region: "europe", expectedTeams: 19 },
  { country: "Greece", countryCode: "GR", league: "Super League", region: "europe", expectedTeams: 14 },
  { country: "Austria", countryCode: "AT", league: "Austrian Bundesliga", region: "europe", expectedTeams: 12 },
  { country: "Switzerland", countryCode: "CH", league: "Super League", region: "europe", expectedTeams: 12 },
  { country: "Sweden", countryCode: "SE", league: "Allsvenskan", region: "europe", expectedTeams: 16 },
  { country: "Norway", countryCode: "NO", league: "Eliteserien", region: "europe", expectedTeams: 16 },
  { country: "Denmark", countryCode: "DK", league: "Superliga", region: "europe", expectedTeams: 12 },
  { country: "Finland", countryCode: "FI", league: "Veikkausliiga", region: "europe", expectedTeams: 12 },
  { country: "Ireland", countryCode: "IE", league: "League of Ireland Premier Division", region: "europe", expectedTeams: 10 },
  { country: "Iceland", countryCode: "IS", league: "Úrvalsdeild", region: "europe", expectedTeams: 12 },
  { country: "Poland", countryCode: "PL", league: "Ekstraklasa", region: "europe", expectedTeams: 18 },
  { country: "Czech Republic", countryCode: "CZ", league: "Czech First League", region: "europe", expectedTeams: 16 },
  { country: "Hungary", countryCode: "HU", league: "NB I", region: "europe", expectedTeams: 12 },
  { country: "Romania", countryCode: "RO", league: "SuperLiga", region: "europe", expectedTeams: 16 },
  { country: "Bulgaria", countryCode: "BG", league: "First Professional Football League", region: "europe", expectedTeams: 16 },
  { country: "Croatia", countryCode: "HR", league: "HNL", region: "europe", expectedTeams: 10 },
  { country: "Serbia", countryCode: "RS", league: "SuperLiga", region: "europe", expectedTeams: 16 },
  { country: "Slovakia", countryCode: "SK", league: "Fortuna Liga", region: "europe", expectedTeams: 12 },
  { country: "Slovenia", countryCode: "SI", league: "PrvaLiga", region: "europe", expectedTeams: 10 },
  { country: "Ukraine", countryCode: "UA", league: "Ukrainian Premier League", region: "europe", expectedTeams: 16 },
  { country: "Russia", countryCode: "RU", league: "Russian Premier League", region: "europe", expectedTeams: 16 },
  { country: "Cyprus", countryCode: "CY", league: "Cypriot First Division", region: "europe", expectedTeams: 14 },
  { country: "Malta", countryCode: "MT", league: "Maltese Premier League", region: "europe", expectedTeams: 16 },
  { country: "Luxembourg", countryCode: "LU", league: "National Division", region: "europe", expectedTeams: 14 },
  { country: "Estonia", countryCode: "EE", league: "Meistriliiga", region: "europe", expectedTeams: 10 },
  { country: "Latvia", countryCode: "LV", league: "Virsliga", region: "europe", expectedTeams: 10 },
  { country: "Lithuania", countryCode: "LT", league: "A Lyga", region: "europe", expectedTeams: 10 },
  { country: "Albania", countryCode: "AL", league: "Kategoria Superiore", region: "europe", expectedTeams: 10 },
  { country: "Bosnia and Herzegovina", countryCode: "BA", league: "Premier League of Bosnia and Herzegovina", region: "europe", expectedTeams: 12 },
  { country: "North Macedonia", countryCode: "MK", league: "Prva Liga", region: "europe", expectedTeams: 10 },
  { country: "Montenegro", countryCode: "ME", league: "Montenegrin First League", region: "europe", expectedTeams: 10 },
  { country: "Kosovo", countryCode: "XK", league: "Football Superleague of Kosovo", region: "europe", expectedTeams: 10 },
  { country: "Moldova", countryCode: "MD", league: "Moldovan Super Liga", region: "europe", expectedTeams: 8 },
  { country: "Georgia", countryCode: "GE", league: "Erovnuli Liga", region: "europe", expectedTeams: 10 },
  { country: "Armenia", countryCode: "AM", league: "Armenian Premier League", region: "europe", expectedTeams: 10 },
  { country: "Azerbaijan", countryCode: "AZ", league: "Azerbaijan Premier League", region: "europe", expectedTeams: 10 },
  { country: "Belarus", countryCode: "BY", league: "Belarusian Premier League", region: "europe", expectedTeams: 16 },
  { country: "Kazakhstan", countryCode: "KZ", league: "Kazakhstan Premier League", region: "europe", expectedTeams: 14 },
  { country: "Andorra", countryCode: "AD", league: null, region: "europe", expectedTeams: 8 },
  { country: "Faroe Islands", countryCode: "FO", league: null, region: "europe", expectedTeams: 10 },
  { country: "Gibraltar", countryCode: "GI", league: null, region: "europe", expectedTeams: 11 },
  { country: "San Marino", countryCode: "SM", league: null, region: "europe", expectedTeams: 15 },

  // ═══════════════════════════════════════════════════════════
  // AFRICA (~40 countries)
  // ═══════════════════════════════════════════════════════════
  { country: "Nigeria", countryCode: "NG", league: "Nigeria Professional Football League", region: "africa", expectedTeams: 20 },
  { country: "Egypt", countryCode: "EG", league: "Egyptian Premier League", region: "africa", expectedTeams: 18 },
  { country: "South Africa", countryCode: "ZA", league: "DStv Premiership", region: "africa", expectedTeams: 16 },
  { country: "Morocco", countryCode: "MA", league: "Botola Pro", region: "africa", expectedTeams: 16 },
  { country: "Tunisia", countryCode: "TN", league: "Ligue Professionnelle 1", region: "africa", expectedTeams: 14 },
  { country: "Algeria", countryCode: "DZ", league: "Ligue Professionnelle 1", region: "africa", expectedTeams: 16 },
  { country: "Ghana", countryCode: "GH", league: "Ghana Premier League", region: "africa", expectedTeams: 18 },
  { country: "Kenya", countryCode: "KE", league: "Kenyan Premier League", region: "africa", expectedTeams: 18 },
  { country: "Rwanda", countryCode: "RW", league: "Rwanda Premier League", region: "africa", expectedTeams: 16 },
  { country: "Tanzania", countryCode: "TZ", league: "NBC Premier League", region: "africa", expectedTeams: 16 },
  { country: "Uganda", countryCode: "UG", league: "Uganda Premier League", region: "africa", expectedTeams: 16 },
  { country: "DR Congo", countryCode: "CD", league: "Linafoot", region: "africa", expectedTeams: 20 },
  { country: "Senegal", countryCode: "SN", league: "Ligue 1 Sénégalaise", region: "africa", expectedTeams: 14 },
  { country: "Côte d'Ivoire", countryCode: "CI", league: "Ligue 1 Ivoirienne", region: "africa", expectedTeams: 14 },
  { country: "Cameroon", countryCode: "CM", league: "Elite One", region: "africa", expectedTeams: 16 },
  { country: "Mali", countryCode: "ML", league: "Première Division du Mali", region: "africa", expectedTeams: 18 },
  { country: "Burkina Faso", countryCode: "BF", league: "Première Division du Burkina Faso", region: "africa", expectedTeams: 16 },
  { country: "Ethiopia", countryCode: "ET", league: "Ethiopian Premier League", region: "africa", expectedTeams: 16 },
  { country: "Zambia", countryCode: "ZM", league: "Zambia Super League", region: "africa", expectedTeams: 18 },
  { country: "Zimbabwe", countryCode: "ZW", league: "Zimbabwe Premier Soccer League", region: "africa", expectedTeams: 18 },
  { country: "Mozambique", countryCode: "MZ", league: "Moçambola", region: "africa", expectedTeams: 14 },
  { country: "Angola", countryCode: "AO", league: "Girabola", region: "africa", expectedTeams: 16 },
  { country: "Guinea", countryCode: "GN", league: "Ligue 1 Guinéenne", region: "africa", expectedTeams: 14 },
  { country: "Niger", countryCode: "NE", league: "Ligue 1 du Niger", region: "africa", expectedTeams: 14 },
  { country: "Togo", countryCode: "TG", league: "Championnat National du Togo", region: "africa", expectedTeams: 14 },
  { country: "Benin", countryCode: "BJ", league: "Championnat National du Bénin", region: "africa", expectedTeams: 12 },
  { country: "Gabon", countryCode: "GA", league: "Championnat National D1 du Gabon", region: "africa", expectedTeams: 14 },
  { country: "Congo", countryCode: "CG", league: "Ligue 1 du Congo", region: "africa", expectedTeams: 14 },
  { country: "Madagascar", countryCode: "MG", league: "Pro League Malgache", region: "africa", expectedTeams: 12 },
  { country: "Sudan", countryCode: "SD", league: "Sudan Premier League", region: "africa", expectedTeams: 18 },
  { country: "Libya", countryCode: "LY", league: "Libyan Premier League", region: "africa", expectedTeams: 18 },
  { country: "Namibia", countryCode: "NA", league: "Namibia Premier League", region: "africa", expectedTeams: 12 },
  { country: "Botswana", countryCode: "BW", league: "BTC Premiership", region: "africa", expectedTeams: 16 },
  { country: "Malawi", countryCode: "MW", league: "Super League of Malawi", region: "africa", expectedTeams: 16 },
  { country: "Sierra Leone", countryCode: "SL", league: "Sierra Leone Premier League", region: "africa", expectedTeams: 14 },
  { country: "Liberia", countryCode: "LR", league: "LFA First Division", region: "africa", expectedTeams: 14 },
  { country: "Gambia", countryCode: "GM", league: "GFF League First Division", region: "africa", expectedTeams: 12 },
  { country: "Burundi", countryCode: "BI", league: "Burundi Premier League", region: "africa", expectedTeams: 16 },
  { country: "Lesotho", countryCode: "LS", league: "Lesotho Premier League", region: "africa", expectedTeams: 12 },
  { country: "Eswatini", countryCode: "SZ", league: "Eswatini Premier League", region: "africa", expectedTeams: 12 },
  { country: "Guinea-Bissau", countryCode: "GW", league: null, region: "africa", expectedTeams: 12 },
  { country: "Cape Verde", countryCode: "CV", league: null, region: "africa", expectedTeams: 12 },
  { country: "Equatorial Guinea", countryCode: "GQ", league: null, region: "africa", expectedTeams: 12 },
  { country: "Mauritius", countryCode: "MU", league: null, region: "africa", expectedTeams: 10 },
  { country: "Seychelles", countryCode: "SC", league: null, region: "africa", expectedTeams: 10 },
  { country: "Djibouti", countryCode: "DJ", league: null, region: "africa", expectedTeams: 10 },
  { country: "Eritrea", countryCode: "ER", league: null, region: "africa", expectedTeams: 12 },
  { country: "Somalia", countryCode: "SO", league: null, region: "africa", expectedTeams: 12 },
  { country: "Mauritania", countryCode: "MR", league: null, region: "africa", expectedTeams: 16 },
  { country: "Chad", countryCode: "TD", league: null, region: "africa", expectedTeams: 12 },
  { country: "Central African Republic", countryCode: "CF", league: null, region: "africa", expectedTeams: 10 },
  { country: "South Sudan", countryCode: "SS", league: null, region: "africa", expectedTeams: 12 },
  { country: "Sao Tome and Principe", countryCode: "ST", league: null, region: "africa", expectedTeams: 10 },
  { country: "Comoros", countryCode: "KM", league: null, region: "africa", expectedTeams: 12 },

  // ═══════════════════════════════════════════════════════════
  // AMERICAS (~25 countries)
  // ═══════════════════════════════════════════════════════════
  { country: "United States", countryCode: "US", league: "Major League Soccer", region: "americas", expectedTeams: 29 },
  { country: "Mexico", countryCode: "MX", league: "Liga MX", region: "americas", expectedTeams: 18 },
  { country: "Canada", countryCode: "CA", league: "Canadian Premier League", region: "americas", expectedTeams: 8 },
  { country: "Brazil", countryCode: "BR", league: "Brasileirão Série A", region: "americas", expectedTeams: 20 },
  { country: "Argentina", countryCode: "AR", league: "Liga Profesional de Fútbol", region: "americas", expectedTeams: 28 },
  { country: "Colombia", countryCode: "CO", league: "Categoría Primera A", region: "americas", expectedTeams: 20 },
  { country: "Chile", countryCode: "CL", league: "Primera División de Chile", region: "americas", expectedTeams: 16 },
  { country: "Peru", countryCode: "PE", league: "Liga 1", region: "americas", expectedTeams: 19 },
  { country: "Ecuador", countryCode: "EC", league: "Liga Pro", region: "americas", expectedTeams: 16 },
  { country: "Uruguay", countryCode: "UY", league: "Primera División de Uruguay", region: "americas", expectedTeams: 16 },
  { country: "Paraguay", countryCode: "PY", league: "División de Honor", region: "americas", expectedTeams: 12 },
  { country: "Bolivia", countryCode: "BO", league: "División Profesional", region: "americas", expectedTeams: 16 },
  { country: "Venezuela", countryCode: "VE", league: "Liga FUTVE", region: "americas", expectedTeams: 18 },
  { country: "Costa Rica", countryCode: "CR", league: "Liga FPD", region: "americas", expectedTeams: 12 },
  { country: "Panama", countryCode: "PA", league: "Liga Panameña de Fútbol", region: "americas", expectedTeams: 10 },
  { country: "Honduras", countryCode: "HN", league: "Liga Nacional de Honduras", region: "americas", expectedTeams: 10 },
  { country: "El Salvador", countryCode: "SV", league: "Primera División de Fútbol", region: "americas", expectedTeams: 12 },
  { country: "Guatemala", countryCode: "GT", league: "Liga Nacional de Guatemala", region: "americas", expectedTeams: 12 },
  { country: "Jamaica", countryCode: "JM", league: "Jamaica Premier League", region: "americas", expectedTeams: 12 },
  { country: "Trinidad and Tobago", countryCode: "TT", league: "TT Pro League", region: "americas", expectedTeams: 10 },
  { country: "Dominican Republic", countryCode: "DO", league: "Liga Dominicana de Fútbol", region: "americas", expectedTeams: 10 },
  { country: "Haiti", countryCode: "HT", league: "Ligue Haïtienne", region: "americas", expectedTeams: 14 },
  { country: "Cuba", countryCode: "CU", league: "Campeonato Nacional de Fútbol de Cuba", region: "americas", expectedTeams: 16 },
  { country: "Nicaragua", countryCode: "NI", league: "Liga Primera de Nicaragua", region: "americas", expectedTeams: 10 },
  { country: "Belize", countryCode: "BZ", league: null, region: "americas", expectedTeams: 10 },
  { country: "Suriname", countryCode: "SR", league: null, region: "americas", expectedTeams: 10 },
  { country: "Guyana", countryCode: "GY", league: null, region: "americas", expectedTeams: 10 },
  { country: "Barbados", countryCode: "BB", league: null, region: "americas", expectedTeams: 12 },
  { country: "Antigua and Barbuda", countryCode: "AG", league: null, region: "americas", expectedTeams: 10 },
  { country: "Dominica", countryCode: "DM", league: null, region: "americas", expectedTeams: 10 },
  { country: "Grenada", countryCode: "GD", league: null, region: "americas", expectedTeams: 10 },
  { country: "Saint Kitts and Nevis", countryCode: "KN", league: null, region: "americas", expectedTeams: 10 },
  { country: "Saint Lucia", countryCode: "LC", league: null, region: "americas", expectedTeams: 10 },
  { country: "Saint Vincent and the Grenadines", countryCode: "VC", league: null, region: "americas", expectedTeams: 8 },
  { country: "Bahamas", countryCode: "BS", league: null, region: "americas", expectedTeams: 10 },
  { country: "Aruba", countryCode: "AW", league: null, region: "americas", expectedTeams: 10 },
  { country: "Curaçao", countryCode: "CW", league: null, region: "americas", expectedTeams: 12 },
  { country: "Puerto Rico", countryCode: "PR", league: null, region: "americas", expectedTeams: 12 },
  { country: "Bermuda", countryCode: "BM", league: null, region: "americas", expectedTeams: 10 },
  { country: "Cayman Islands", countryCode: "KY", league: null, region: "americas", expectedTeams: 10 },
  { country: "British Virgin Islands", countryCode: "VG", league: null, region: "americas", expectedTeams: 10 },
  { country: "US Virgin Islands", countryCode: "VI", league: null, region: "americas", expectedTeams: 10 },
  { country: "Turks and Caicos Islands", countryCode: "TC", league: null, region: "americas", expectedTeams: 10 },
  { country: "Guadeloupe", countryCode: "GP", league: null, region: "americas", expectedTeams: 14 },
  { country: "Martinique", countryCode: "MQ", league: null, region: "americas", expectedTeams: 14 },
  { country: "Sint Maarten", countryCode: "SX", league: null, region: "americas", expectedTeams: 8 },
];

/** Get all leagues for a specific region. */
export function leaguesForRegion(
  region: "europe" | "africa" | "americas" | "all",
): LeagueEntry[] {
  if (region === "all") return LEAGUE_CATALOG;
  return LEAGUE_CATALOG.filter((l) => l.region === region);
}

export function leagueForCountryCode(code: string): LeagueEntry | undefined {
  return LEAGUE_CATALOG.find((entry) => entry.countryCode === code);
}

export const EXPECTED_TEAM_TOTAL = LEAGUE_CATALOG.reduce(
  (total, entry) => total + entry.expectedTeams,
  0,
);
