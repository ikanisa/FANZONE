// In-memory team search database for onboarding and team selection.
//
// Provides a searchable local database of football teams grouped by region.
// Used in:
//   - Onboarding flow (steps 5 & 6)
//   - Settings → Favorite Teams screen
//
// NOTE: This is a candidate for migration to a Supabase-backed table if
// the team list grows significantly.

/// Minimal team data for onboarding search.
class OnboardingTeam {
  const OnboardingTeam({
    required this.id,
    required this.name,
    required this.country,
    this.league,
    this.aliases = const [],
    this.region = 'global',
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String country;
  final String? league;
  final List<String> aliases;
  final String region;
  final bool isPopular;

  /// Short display name — uses first alias if available, else full name.
  String get shortName {
    if (aliases.isNotEmpty) return aliases.first;
    // For long names, try to abbreviate
    if (name.length > 12) {
      // Remove common prefixes like 'FC ', 'AFC ', etc.
      final clean = name
          .replaceFirst(RegExp(r'^(FC |AFC |AC |AS |SS |SSC |ACF |VfL |RB )'), '')
          .replaceFirst(RegExp(r' FC$| CF$| SC$| AC$'), '');
      return clean.length < name.length ? clean : name;
    }
    return name;
  }

  /// Resolved crest URL — returns null since crests are not bundled.
  /// The UI falls back to a letter-avatar when this is null.
  String? get resolvedCrestUrl => null;

  /// Emoji fallback for team logo display.
  String get logoEmoji => '⚽';

  /// ISO 3166-1 alpha-2 country code derived from the country name.
  String get countryCode => _countryToCode[country] ?? country.substring(0, 2).toUpperCase();

  static const _countryToCode = <String, String>{
    'England': 'GB',
    'Spain': 'ES',
    'Italy': 'IT',
    'Germany': 'DE',
    'France': 'FR',
    'Malta': 'MT',
    'Rwanda': 'RW',
    'Egypt': 'EG',
    'South Africa': 'ZA',
    'Tunisia': 'TN',
    'Morocco': 'MA',
    'DR Congo': 'CD',
    'Tanzania': 'TZ',
    'Brazil': 'BR',
    'Argentina': 'AR',
    'Netherlands': 'NL',
    'Belgium': 'BE',
    'Portugal': 'PT',
    'Nigeria': 'NG',
    'Ghana': 'GH',
    'Senegal': 'SN',
    'Cameroon': 'CM',
    'Japan': 'JP',
    'South Korea': 'KR',
    'United States': 'US',
    'Mexico': 'MX',
  };
}


/// Public accessor for the full team database.
List<OnboardingTeam> get allTeams => _allTeams;

/// Search teams by name or alias. Case-insensitive, limit results.
List<OnboardingTeam> searchTeams(String query, {int limit = 10}) {
  if (query.trim().isEmpty) return const [];

  final q = query.toLowerCase().trim();
  final results = _allTeams.where((t) {
    if (t.name.toLowerCase().contains(q)) return true;
    for (final alias in t.aliases) {
      if (alias.toLowerCase().contains(q)) return true;
    }
    return false;
  }).take(limit).toList();

  return results;
}

/// Get popular teams for a given region (for the onboarding grid display).
List<OnboardingTeam> popularTeamsForRegion(String region) {
  if (region == 'global') {
    return _allTeams.where((t) => t.isPopular).toList();
  }
  final regional = _allTeams
      .where((t) => t.region == region && t.isPopular)
      .toList();
  // If region has few popular teams, pad with global popular
  if (regional.length < 8) {
    final globalPopular = _allTeams
        .where((t) => t.isPopular && !regional.contains(t))
        .take(8 - regional.length);
    return [...regional, ...globalPopular];
  }
  return regional;
}

// ═════════════════════════════════════════════════════════════
// Team Database
// ═════════════════════════════════════════════════════════════

const _allTeams = <OnboardingTeam>[
  // ── English Premier League ──
  OnboardingTeam(id: 'epl-ars', name: 'Arsenal', country: 'England', league: 'Premier League', region: 'europe', isPopular: true, aliases: ['Gunners']),
  OnboardingTeam(id: 'epl-avl', name: 'Aston Villa', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Villa', 'Villans']),
  OnboardingTeam(id: 'epl-bou', name: 'AFC Bournemouth', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Bournemouth', 'Cherries']),
  OnboardingTeam(id: 'epl-bre', name: 'Brentford', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Bees']),
  OnboardingTeam(id: 'epl-bha', name: 'Brighton & Hove Albion', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Brighton', 'Seagulls']),
  OnboardingTeam(id: 'epl-che', name: 'Chelsea', country: 'England', league: 'Premier League', region: 'europe', isPopular: true, aliases: ['Blues']),
  OnboardingTeam(id: 'epl-cry', name: 'Crystal Palace', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Palace', 'Eagles']),
  OnboardingTeam(id: 'epl-eve', name: 'Everton', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Toffees']),
  OnboardingTeam(id: 'epl-ful', name: 'Fulham', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Cottagers']),
  OnboardingTeam(id: 'epl-ips', name: 'Ipswich Town', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Tractor Boys']),
  OnboardingTeam(id: 'epl-lei', name: 'Leicester City', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Foxes']),
  OnboardingTeam(id: 'epl-liv', name: 'Liverpool', country: 'England', league: 'Premier League', region: 'europe', isPopular: true, aliases: ['Reds', 'LFC']),
  OnboardingTeam(id: 'epl-mci', name: 'Manchester City', country: 'England', league: 'Premier League', region: 'europe', isPopular: true, aliases: ['Man City', 'City', 'Citizens']),
  OnboardingTeam(id: 'epl-mun', name: 'Manchester United', country: 'England', league: 'Premier League', region: 'europe', isPopular: true, aliases: ['Man Utd', 'United', 'Red Devils']),
  OnboardingTeam(id: 'epl-new', name: 'Newcastle United', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Newcastle', 'Magpies', 'Toon']),
  OnboardingTeam(id: 'epl-nfo', name: 'Nottingham Forest', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Forest']),
  OnboardingTeam(id: 'epl-sou', name: 'Southampton', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Saints']),
  OnboardingTeam(id: 'epl-tot', name: 'Tottenham Hotspur', country: 'England', league: 'Premier League', region: 'europe', isPopular: true, aliases: ['Spurs', 'Tottenham']),
  OnboardingTeam(id: 'epl-whu', name: 'West Ham United', country: 'England', league: 'Premier League', region: 'europe', aliases: ['West Ham', 'Hammers', 'Irons']),
  OnboardingTeam(id: 'epl-wol', name: 'Wolverhampton Wanderers', country: 'England', league: 'Premier League', region: 'europe', aliases: ['Wolves']),

  // ── La Liga ──
  OnboardingTeam(id: 'lla-bar', name: 'FC Barcelona', country: 'Spain', league: 'La Liga', region: 'europe', isPopular: true, aliases: ['Barcelona', 'Barça', 'Barca']),
  OnboardingTeam(id: 'lla-rma', name: 'Real Madrid', country: 'Spain', league: 'La Liga', region: 'europe', isPopular: true, aliases: ['Madrid', 'Los Blancos']),
  OnboardingTeam(id: 'lla-atm', name: 'Atlético Madrid', country: 'Spain', league: 'La Liga', region: 'europe', aliases: ['Atletico', 'Colchoneros']),
  OnboardingTeam(id: 'lla-rsoc', name: 'Real Sociedad', country: 'Spain', league: 'La Liga', region: 'europe', aliases: ['Sociedad', 'La Real']),
  OnboardingTeam(id: 'lla-rbe', name: 'Real Betis', country: 'Spain', league: 'La Liga', region: 'europe', aliases: ['Betis']),
  OnboardingTeam(id: 'lla-sev', name: 'Sevilla FC', country: 'Spain', league: 'La Liga', region: 'europe', aliases: ['Sevilla']),
  OnboardingTeam(id: 'lla-vil', name: 'Villarreal CF', country: 'Spain', league: 'La Liga', region: 'europe', aliases: ['Villarreal', 'Yellow Submarine']),
  OnboardingTeam(id: 'lla-ath', name: 'Athletic Bilbao', country: 'Spain', league: 'La Liga', region: 'europe', aliases: ['Athletic', 'Bilbao']),

  // ── Serie A ──
  OnboardingTeam(id: 'sa-juv', name: 'Juventus', country: 'Italy', league: 'Serie A', region: 'europe', isPopular: true, aliases: ['Juve', 'Old Lady', 'Bianconeri']),
  OnboardingTeam(id: 'sa-mil', name: 'AC Milan', country: 'Italy', league: 'Serie A', region: 'europe', isPopular: true, aliases: ['Milan', 'Rossoneri']),
  OnboardingTeam(id: 'sa-int', name: 'Inter Milan', country: 'Italy', league: 'Serie A', region: 'europe', isPopular: true, aliases: ['Inter', 'Internazionale', 'Nerazzurri']),
  OnboardingTeam(id: 'sa-nap', name: 'SSC Napoli', country: 'Italy', league: 'Serie A', region: 'europe', aliases: ['Napoli', 'Partenopei']),
  OnboardingTeam(id: 'sa-rom', name: 'AS Roma', country: 'Italy', league: 'Serie A', region: 'europe', aliases: ['Roma', 'Giallorossi']),
  OnboardingTeam(id: 'sa-laz', name: 'SS Lazio', country: 'Italy', league: 'Serie A', region: 'europe', aliases: ['Lazio', 'Biancocelesti']),
  OnboardingTeam(id: 'sa-ata', name: 'Atalanta', country: 'Italy', league: 'Serie A', region: 'europe', aliases: ['Dea', 'Goddess']),
  OnboardingTeam(id: 'sa-fio', name: 'ACF Fiorentina', country: 'Italy', league: 'Serie A', region: 'europe', aliases: ['Fiorentina', 'Viola']),

  // ── Bundesliga ──
  OnboardingTeam(id: 'bl-bay', name: 'Bayern Munich', country: 'Germany', league: 'Bundesliga', region: 'europe', isPopular: true, aliases: ['Bayern', 'FCB', 'Bavarians']),
  OnboardingTeam(id: 'bl-bvb', name: 'Borussia Dortmund', country: 'Germany', league: 'Bundesliga', region: 'europe', isPopular: true, aliases: ['Dortmund', 'BVB', 'Yellow Wall']),
  OnboardingTeam(id: 'bl-rbl', name: 'RB Leipzig', country: 'Germany', league: 'Bundesliga', region: 'europe', aliases: ['Leipzig']),
  OnboardingTeam(id: 'bl-lev', name: 'Bayer Leverkusen', country: 'Germany', league: 'Bundesliga', region: 'europe', aliases: ['Leverkusen']),
  OnboardingTeam(id: 'bl-sch', name: 'FC Schalke 04', country: 'Germany', league: 'Bundesliga', region: 'europe', aliases: ['Schalke']),
  OnboardingTeam(id: 'bl-wob', name: 'VfL Wolfsburg', country: 'Germany', league: 'Bundesliga', region: 'europe', aliases: ['Wolfsburg']),

  // ── Ligue 1 ──
  OnboardingTeam(id: 'l1-psg', name: 'Paris Saint-Germain', country: 'France', league: 'Ligue 1', region: 'europe', isPopular: true, aliases: ['PSG', 'Paris']),
  OnboardingTeam(id: 'l1-mar', name: 'Olympique de Marseille', country: 'France', league: 'Ligue 1', region: 'europe', aliases: ['Marseille', 'OM']),
  OnboardingTeam(id: 'l1-lyo', name: 'Olympique Lyonnais', country: 'France', league: 'Ligue 1', region: 'europe', aliases: ['Lyon', 'OL']),
  OnboardingTeam(id: 'l1-mon', name: 'AS Monaco', country: 'France', league: 'Ligue 1', region: 'europe', aliases: ['Monaco']),
  OnboardingTeam(id: 'l1-lil', name: 'Lille OSC', country: 'France', league: 'Ligue 1', region: 'europe', aliases: ['Lille', 'LOSC']),

  // ── Maltese Premier League ──
  OnboardingTeam(id: 'mt-hib', name: 'Hibernians FC', country: 'Malta', league: 'Maltese Premier League', region: 'malta', isPopular: true, aliases: ['Hibernians', 'Hibs']),
  OnboardingTeam(id: 'mt-val', name: 'Valletta FC', country: 'Malta', league: 'Maltese Premier League', region: 'malta', isPopular: true, aliases: ['Valletta']),
  OnboardingTeam(id: 'mt-flo', name: 'Floriana FC', country: 'Malta', league: 'Maltese Premier League', region: 'malta', isPopular: true, aliases: ['Floriana', 'Greens']),
  OnboardingTeam(id: 'mt-sli', name: 'Sliema Wanderers', country: 'Malta', league: 'Maltese Premier League', region: 'malta', isPopular: true, aliases: ['Sliema']),
  OnboardingTeam(id: 'mt-ham', name: 'Ħamrun Spartans', country: 'Malta', league: 'Maltese Premier League', region: 'malta', isPopular: true, aliases: ['Hamrun', 'Spartans']),
  OnboardingTeam(id: 'mt-bir', name: 'Birkirkara FC', country: 'Malta', league: 'Maltese Premier League', region: 'malta', isPopular: true, aliases: ['Birkirkara']),
  OnboardingTeam(id: 'mt-gzi', name: 'Gżira United', country: 'Malta', league: 'Maltese Premier League', region: 'malta', isPopular: true, aliases: ['Gzira']),
  OnboardingTeam(id: 'mt-sta', name: 'Santa Lucia FC', country: 'Malta', league: 'Maltese Premier League', region: 'malta', aliases: ['Santa Lucia']),

  // ── Rwanda Premier League ──
  OnboardingTeam(id: 'rw-apr', name: 'APR FC', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', isPopular: true, aliases: ['APR', 'Army Patriots']),
  OnboardingTeam(id: 'rw-ray', name: 'Rayon Sports', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', isPopular: true, aliases: ['Rayon', 'Gikundiro']),
  OnboardingTeam(id: 'rw-kiy', name: 'Kiyovu Sports', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', isPopular: true, aliases: ['Kiyovu']),
  OnboardingTeam(id: 'rw-pol', name: 'Police FC', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', isPopular: true, aliases: ['Police']),
  OnboardingTeam(id: 'rw-mus', name: 'Musanze FC', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', isPopular: true, aliases: ['Musanze']),
  OnboardingTeam(id: 'rw-gas', name: 'Gasogi United', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', aliases: ['Gasogi']),
  OnboardingTeam(id: 'rw-mar', name: 'Marines FC', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', aliases: ['Marines']),
  OnboardingTeam(id: 'rw-sun', name: 'Sunrise FC', country: 'Rwanda', league: 'Rwanda Premier League', region: 'africa', aliases: ['Sunrise']),

  // ── African Giants ──
  OnboardingTeam(id: 'af-ala', name: 'Al Ahly', country: 'Egypt', league: 'Egyptian Premier League', region: 'africa', isPopular: true, aliases: ['Ahly']),
  OnboardingTeam(id: 'af-kch', name: 'Kaizer Chiefs', country: 'South Africa', league: 'PSL', region: 'africa', isPopular: true, aliases: ['Chiefs', 'Amakhosi']),
  OnboardingTeam(id: 'af-orl', name: 'Orlando Pirates', country: 'South Africa', league: 'PSL', region: 'africa', aliases: ['Pirates', 'Bucs']),
  OnboardingTeam(id: 'af-mam', name: 'Mamelodi Sundowns', country: 'South Africa', league: 'PSL', region: 'africa', isPopular: true, aliases: ['Sundowns', 'Brazilians']),
  OnboardingTeam(id: 'af-espt', name: 'Espérance de Tunis', country: 'Tunisia', league: 'Ligue 1', region: 'africa', aliases: ['Esperance', 'Taraji']),
  OnboardingTeam(id: 'af-wyd', name: 'Wydad AC', country: 'Morocco', league: 'Botola', region: 'africa', aliases: ['Wydad', 'WAC']),
  OnboardingTeam(id: 'af-tpm', name: 'TP Mazembe', country: 'DR Congo', league: 'Linafoot', region: 'africa', aliases: ['Mazembe']),
  OnboardingTeam(id: 'af-ybs', name: 'Young Africans SC', country: 'Tanzania', league: 'NBCPL', region: 'africa', aliases: ['Yanga', 'Young Africans']),

  // ── South American ──
  OnboardingTeam(id: 'sa-fla', name: 'Flamengo', country: 'Brazil', league: 'Brasileirão', region: 'americas', isPopular: true, aliases: ['Mengão', 'Fla']),
  OnboardingTeam(id: 'sa-boc', name: 'Boca Juniors', country: 'Argentina', league: 'Liga Profesional', region: 'americas', isPopular: true, aliases: ['Boca', 'Xeneizes']),
  OnboardingTeam(id: 'sa-riv', name: 'River Plate', country: 'Argentina', league: 'Liga Profesional', region: 'americas', aliases: ['River', 'Millonarios']),
  OnboardingTeam(id: 'sa-pal', name: 'Palmeiras', country: 'Brazil', league: 'Brasileirão', region: 'americas', aliases: ['Verdão']),
  OnboardingTeam(id: 'sa-cor', name: 'Corinthians', country: 'Brazil', league: 'Brasileirão', region: 'americas', aliases: ['Timão']),

  // ── National Teams ──
  OnboardingTeam(id: 'nt-bra', name: 'Brazil', country: 'Brazil', league: 'FIFA', region: 'global', isPopular: true, aliases: ['Seleção', 'Canarinha']),
  OnboardingTeam(id: 'nt-arg', name: 'Argentina', country: 'Argentina', league: 'FIFA', region: 'global', isPopular: true, aliases: ['La Albiceleste']),
  OnboardingTeam(id: 'nt-fra', name: 'France', country: 'France', league: 'FIFA', region: 'global', isPopular: true, aliases: ['Les Bleus']),
  OnboardingTeam(id: 'nt-ger', name: 'Germany', country: 'Germany', league: 'FIFA', region: 'global', isPopular: true, aliases: ['Die Mannschaft']),
  OnboardingTeam(id: 'nt-eng', name: 'England', country: 'England', league: 'FIFA', region: 'global', isPopular: true, aliases: ['Three Lions']),
  OnboardingTeam(id: 'nt-esp', name: 'Spain', country: 'Spain', league: 'FIFA', region: 'global', isPopular: true, aliases: ['La Roja']),
  OnboardingTeam(id: 'nt-ita', name: 'Italy', country: 'Italy', league: 'FIFA', region: 'global', aliases: ['Azzurri']),
  OnboardingTeam(id: 'nt-por', name: 'Portugal', country: 'Portugal', league: 'FIFA', region: 'global', aliases: ['Seleção das Quinas']),
  OnboardingTeam(id: 'nt-ned', name: 'Netherlands', country: 'Netherlands', league: 'FIFA', region: 'global', aliases: ['Oranje', 'Holland']),
  OnboardingTeam(id: 'nt-bel', name: 'Belgium', country: 'Belgium', league: 'FIFA', region: 'global', aliases: ['Red Devils']),
  OnboardingTeam(id: 'nt-rwa', name: 'Rwanda', country: 'Rwanda', league: 'FIFA', region: 'africa', isPopular: true, aliases: ['Amavubi']),
  OnboardingTeam(id: 'nt-mlt', name: 'Malta', country: 'Malta', league: 'FIFA', region: 'malta', isPopular: true, aliases: ['Knights']),
  OnboardingTeam(id: 'nt-nig', name: 'Nigeria', country: 'Nigeria', league: 'FIFA', region: 'africa', isPopular: true, aliases: ['Super Eagles']),
  OnboardingTeam(id: 'nt-gha', name: 'Ghana', country: 'Ghana', league: 'FIFA', region: 'africa', aliases: ['Black Stars']),
  OnboardingTeam(id: 'nt-sen', name: 'Senegal', country: 'Senegal', league: 'FIFA', region: 'africa', isPopular: true, aliases: ['Lions of Teranga']),
  OnboardingTeam(id: 'nt-cmr', name: 'Cameroon', country: 'Cameroon', league: 'FIFA', region: 'africa', aliases: ['Indomitable Lions']),
  OnboardingTeam(id: 'nt-mar', name: 'Morocco', country: 'Morocco', league: 'FIFA', region: 'africa', isPopular: true, aliases: ['Atlas Lions']),
  OnboardingTeam(id: 'nt-jap', name: 'Japan', country: 'Japan', league: 'FIFA', region: 'global', aliases: ['Samurai Blue']),
  OnboardingTeam(id: 'nt-kor', name: 'South Korea', country: 'South Korea', league: 'FIFA', region: 'global', aliases: ['Taegeuk Warriors']),
  OnboardingTeam(id: 'nt-usa', name: 'United States', country: 'United States', league: 'FIFA', region: 'americas', aliases: ['USMNT', 'Stars and Stripes']),
  OnboardingTeam(id: 'nt-mex', name: 'Mexico', country: 'Mexico', league: 'FIFA', region: 'americas', aliases: ['El Tri']),
];
