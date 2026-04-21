import 'dart:convert';

class OnboardingTeam {
  const OnboardingTeam({
    required this.id,
    required this.name,
    required this.country,
    this.league,
    this.aliases = const <String>[],
    this.region = 'global',
    this.isPopular = false,
    this.shortNameOverride,
    this.crestUrl,
    this.countryCodeOverride,
    this.popularRank,
  });

  factory OnboardingTeam.fromJson(Map<String, dynamic> json) {
    final rawPopularRank =
        json['popularRank'] ??
        json['popular_rank'] ??
        json['popular_pick_rank'] ??
        json['sort_order'] ??
        json['display_order'] ??
        json['rank'];

    return OnboardingTeam(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      league: json['league']?.toString(),
      aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      region: json['region']?.toString() ?? 'global',
      isPopular: json['isPopular'] == true || json['is_popular'] == true,
      shortNameOverride:
          json['shortName']?.toString() ?? json['short_name']?.toString(),
      crestUrl: json['crestUrl']?.toString() ?? json['crest_url']?.toString(),
      countryCodeOverride:
          json['countryCode']?.toString() ?? json['country_code']?.toString(),
      popularRank: rawPopularRank is num
          ? rawPopularRank.toInt()
          : int.tryParse(rawPopularRank?.toString() ?? ''),
    );
  }

  final String id;
  final String name;
  final String country;
  final String? league;
  final List<String> aliases;
  final String region;
  final bool isPopular;
  final String? shortNameOverride;
  final String? crestUrl;
  final String? countryCodeOverride;
  final int? popularRank;

  String get shortName {
    final override = shortNameOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    if (aliases.isNotEmpty) return aliases.first;
    if (name.length > 12) {
      final clean = name
          .replaceFirst(
            RegExp(r'^(FC |AFC |AC |AS |SS |SSC |ACF |VfL |RB )'),
            '',
          )
          .replaceFirst(RegExp(r' FC$| CF$| SC$| AC$'), '');
      return clean.length < name.length ? clean : name;
    }
    return name;
  }

  String? get resolvedCrestUrl => crestUrl;

  String get logoEmoji => '⚽';

  String get countryCode {
    final override = countryCodeOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override.toUpperCase();
    }
    final normalizedCountry = country.trim();
    if (normalizedCountry.isEmpty) return 'FC';
    return _countryToCode[normalizedCountry] ??
        normalizedCountry
            .substring(0, normalizedCountry.length >= 2 ? 2 : 1)
            .toUpperCase();
  }

  OnboardingTeam mergedWith(OnboardingTeam fallback) {
    if (fallback.id != id) return this;
    return OnboardingTeam(
      id: id,
      name: name.isNotEmpty ? name : fallback.name,
      country: country.isNotEmpty ? country : fallback.country,
      league: league ?? fallback.league,
      aliases: aliases.isNotEmpty ? aliases : fallback.aliases,
      region: region != 'global' || fallback.region == 'global'
          ? region
          : fallback.region,
      isPopular: isPopular || fallback.isPopular,
      shortNameOverride: shortNameOverride ?? fallback.shortNameOverride,
      crestUrl: crestUrl ?? fallback.crestUrl,
      countryCodeOverride: countryCodeOverride ?? fallback.countryCodeOverride,
      popularRank: popularRank ?? fallback.popularRank,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'league': league,
      'aliases': aliases,
      'region': region,
      'is_popular': isPopular,
      'short_name': shortNameOverride,
      'crest_url': crestUrl,
      'country_code': countryCodeOverride ?? countryCode,
      'popular_rank': popularRank,
    };
  }

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

class FavoriteTeamRecordDto {
  const FavoriteTeamRecordDto({
    required this.teamId,
    required this.teamName,
    this.teamShortName,
    this.teamCountry,
    this.teamCountryCode,
    this.teamLeague,
    this.teamCrestUrl,
    this.source = 'popular',
    this.sortOrder = 0,
    this.updatedAt,
  });

  factory FavoriteTeamRecordDto.fromJson(Map<String, dynamic> json) {
    return FavoriteTeamRecordDto(
      teamId: json['team_id']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? '',
      teamShortName: json['team_short_name']?.toString(),
      teamCountry: json['team_country']?.toString(),
      teamCountryCode: json['team_country_code']?.toString(),
      teamLeague: json['team_league']?.toString(),
      teamCrestUrl: json['team_crest_url']?.toString(),
      source: json['source']?.toString() ?? 'popular',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );
  }

  final String teamId;
  final String teamName;
  final String? teamShortName;
  final String? teamCountry;
  final String? teamCountryCode;
  final String? teamLeague;
  final String? teamCrestUrl;
  final String source;
  final int sortOrder;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'team_name': teamName,
      'team_short_name': teamShortName,
      'team_country': teamCountry,
      'team_country_code': teamCountryCode,
      'team_league': teamLeague,
      'team_crest_url': teamCrestUrl,
      'source': source,
      'sort_order': sortOrder,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  dynamic operator [](String key) => toJson()[key];
}

class TeamSearchCatalog {
  TeamSearchCatalog(
    List<OnboardingTeam> teams, {
    List<OnboardingTeam>? popularTeams,
  }) : allTeams = _dedupeTeams(teams),
       _byId = {for (final team in _dedupeTeams(teams)) team.id: team},
       popularTeams = _resolvePopularTeams(_dedupeTeams(teams), popularTeams);

  factory TeamSearchCatalog.defaults() {
    return TeamSearchCatalog(_bundledFallbackTeams);
  }

  factory TeamSearchCatalog.fromRawJson(String raw) {
    final decoded = jsonDecode(raw);
    final payload = decoded is Map<String, dynamic>
        ? (decoded['teams'] as List<dynamic>? ?? const <dynamic>[])
        : decoded as List<dynamic>;
    final popularPayload = decoded is Map<String, dynamic>
        ? (decoded['popular_teams'] as List<dynamic>? ??
              decoded['popularTeams'] as List<dynamic>? ??
              const <dynamic>[])
        : const <dynamic>[];

    final teams = payload
        .whereType<Map>()
        .map((row) => OnboardingTeam.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final popularTeams = popularPayload
        .whereType<Map>()
        .map((row) => OnboardingTeam.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return TeamSearchCatalog(teams, popularTeams: popularTeams);
  }

  final List<OnboardingTeam> allTeams;
  final List<OnboardingTeam> popularTeams;
  final Map<String, OnboardingTeam> _byId;

  OnboardingTeam? byId(String teamId) => _byId[teamId];

  List<OnboardingTeam> search(String query, {int limit = 10}) {
    return searchLocal(query, limit: limit);
  }

  List<OnboardingTeam> searchLocal(String query, {int limit = 10}) {
    return _searchIn(allTeams, query, limit: limit);
  }

  List<OnboardingTeam> searchPopular(String query, {int limit = 10}) {
    final pool = popularTeams.isNotEmpty ? popularTeams : _popularSearchPool;
    return _searchIn(pool, query, limit: limit);
  }

  List<OnboardingTeam> popularForRegion(String region) {
    final normalizedRegion = _normalizeRegion(region);
    final rankedPopular = popularTeams.isNotEmpty
        ? popularTeams
        : _sortPopularTeams(
            allTeams.where((team) => team.isPopular).toList(growable: false),
          );
    if (rankedPopular.isEmpty) {
      final europeanFallback = _sortPopularTeams(
        allTeams
            .where((team) => _normalizeRegion(team.region) == 'europe')
            .toList(growable: false),
      );
      return europeanFallback.take(20).toList(growable: false);
    }

    if (normalizedRegion == 'global') {
      return rankedPopular.take(20).toList(growable: false);
    }

    final regional = rankedPopular
        .where((team) => _normalizeRegion(team.region) == normalizedRegion)
        .toList(growable: false);
    final padded = <OnboardingTeam>[
      ...regional,
      ...rankedPopular.where(
        (team) =>
            _normalizeRegion(team.region) != normalizedRegion &&
            !regional.any((existing) => existing.id == team.id),
      ),
    ];

    return padded.take(20).toList(growable: false);
  }

  List<OnboardingTeam> get _popularSearchPool {
    final rankedPopular = popularForRegion('europe');
    if (rankedPopular.isNotEmpty) return rankedPopular;
    return allTeams;
  }

  static List<OnboardingTeam> _dedupeTeams(List<OnboardingTeam> teams) {
    final byId = <String, OnboardingTeam>{};
    for (final team in teams) {
      if (team.id.isEmpty || team.name.isEmpty) continue;
      byId[team.id] = team;
    }
    return byId.values.toList(growable: false);
  }

  static List<OnboardingTeam> _resolvePopularTeams(
    List<OnboardingTeam> allTeams,
    List<OnboardingTeam>? popularTeams,
  ) {
    final byId = {for (final team in allTeams) team.id: team};
    final source = popularTeams == null || popularTeams.isEmpty
        ? allTeams.where((team) => team.isPopular).toList(growable: false)
        : popularTeams;

    final resolved = source
        .where((team) => team.id.isNotEmpty && team.name.isNotEmpty)
        .map((team) => team.mergedWith(byId[team.id] ?? team))
        .toList(growable: false);

    return _sortPopularTeams(_dedupeTeams(resolved));
  }

  static List<OnboardingTeam> _sortPopularTeams(List<OnboardingTeam> teams) {
    final sorted = List<OnboardingTeam>.from(teams);
    sorted.sort((left, right) {
      final leftRank = left.popularRank ?? 1 << 20;
      final rightRank = right.popularRank ?? 1 << 20;
      final rankCompare = leftRank.compareTo(rightRank);
      if (rankCompare != 0) return rankCompare;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return List<OnboardingTeam>.unmodifiable(sorted);
  }

  static List<OnboardingTeam> _searchIn(
    List<OnboardingTeam> teams,
    String query, {
    required int limit,
  }) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return const [];

    final scored = <_ScoredOnboardingTeam>[];
    for (final team in teams) {
      final score = _scoreTeam(team, normalized);
      if (score <= 0) continue;
      scored.add(_ScoredOnboardingTeam(team: team, score: score));
    }

    scored.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) return scoreCompare;
      final leftRank = left.team.popularRank ?? 1 << 20;
      final rightRank = right.team.popularRank ?? 1 << 20;
      final rankCompare = leftRank.compareTo(rightRank);
      if (rankCompare != 0) return rankCompare;
      return left.team.name.toLowerCase().compareTo(
        right.team.name.toLowerCase(),
      );
    });

    return scored
        .take(limit)
        .map((entry) => entry.team)
        .toList(growable: false);
  }

  static int _scoreTeam(OnboardingTeam team, String query) {
    final name = _normalize(team.name);
    final shortName = _normalize(team.shortName);
    final country = _normalize(team.country);
    final league = _normalize(team.league ?? '');
    final aliases = team.aliases
        .map(_normalize)
        .where((alias) => alias.isNotEmpty)
        .toList(growable: false);
    final tokens = query.split(' ').where((token) => token.isNotEmpty).toList();

    var score = 0;
    if (name == query) score += 1200;
    if (shortName == query) score += 1120;
    if (aliases.contains(query)) score += 1080;
    if (name.startsWith(query)) score += 980;
    if (shortName.startsWith(query)) score += 920;
    if (aliases.any((alias) => alias.startsWith(query))) score += 900;
    if (name.contains(query)) score += 780;
    if (shortName.contains(query)) score += 720;
    if (aliases.any((alias) => alias.contains(query))) score += 700;
    if (country.contains(query)) score += 280;
    if (league.contains(query)) score += 220;

    for (final token in tokens) {
      if (token.length < 2) continue;
      if (name.split(' ').any((part) => part.startsWith(token))) score += 130;
      if (aliases.any(
        (alias) => alias.split(' ').any((part) => part.startsWith(token)),
      )) {
        score += 90;
      }
    }

    return score;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _normalizeRegion(String value) {
    switch (value.trim().toLowerCase()) {
      case 'africa':
        return 'africa';
      case 'europe':
        return 'europe';
      case 'malta':
        return 'malta';
      case 'americas':
      case 'north_america':
      case 'northamerica':
        return 'north_america';
      default:
        return 'global';
    }
  }
}

class _ScoredOnboardingTeam {
  const _ScoredOnboardingTeam({required this.team, required this.score});

  final OnboardingTeam team;
  final int score;
}

const _bundledFallbackTeams = <OnboardingTeam>[
  OnboardingTeam(
    id: 'gb-liverpool',
    name: 'Liverpool',
    country: 'England',
    league: 'Premier League',
    aliases: ['LIV', 'Reds'],
    region: 'europe',
    isPopular: true,
    popularRank: 1,
  ),
  OnboardingTeam(
    id: 'gb-arsenal',
    name: 'Arsenal',
    country: 'England',
    league: 'Premier League',
    aliases: ['ARS', 'Gunners'],
    region: 'europe',
    isPopular: true,
    popularRank: 2,
  ),
  OnboardingTeam(
    id: 'gb-manchester-city',
    name: 'Manchester City',
    country: 'England',
    league: 'Premier League',
    aliases: ['Man City', 'City'],
    region: 'europe',
    isPopular: true,
    popularRank: 3,
  ),
  OnboardingTeam(
    id: 'gb-manchester-united',
    name: 'Manchester United',
    country: 'England',
    league: 'Premier League',
    aliases: ['Man United', 'United'],
    region: 'europe',
    isPopular: true,
    popularRank: 4,
  ),
  OnboardingTeam(
    id: 'es-real-madrid',
    name: 'Real Madrid',
    country: 'Spain',
    league: 'La Liga',
    aliases: ['Madrid', 'RMA'],
    region: 'europe',
    isPopular: true,
    popularRank: 5,
  ),
  OnboardingTeam(
    id: 'es-barcelona',
    name: 'Barcelona',
    country: 'Spain',
    league: 'La Liga',
    aliases: ['Barca', 'FCB'],
    region: 'europe',
    isPopular: true,
    popularRank: 6,
  ),
  OnboardingTeam(
    id: 'de-bayern',
    name: 'Bayern Munich',
    country: 'Germany',
    league: 'Bundesliga',
    aliases: ['Bayern'],
    region: 'europe',
    isPopular: true,
    popularRank: 7,
  ),
  OnboardingTeam(
    id: 'it-juventus',
    name: 'Juventus',
    country: 'Italy',
    league: 'Serie A',
    aliases: ['Juve'],
    region: 'europe',
    isPopular: true,
    popularRank: 8,
  ),
  OnboardingTeam(
    id: 'england',
    name: 'England',
    country: 'England',
    league: 'National Team',
    aliases: ['Three Lions'],
    region: 'europe',
    isPopular: true,
    popularRank: 9,
  ),
  OnboardingTeam(
    id: 'rw-apr-fc',
    name: 'APR FC',
    country: 'Rwanda',
    league: 'Rwanda Premier League',
    aliases: ['APR'],
    region: 'africa',
    isPopular: true,
    popularRank: 10,
  ),
  OnboardingTeam(
    id: 'rw-rayon-sports',
    name: 'Rayon Sports',
    country: 'Rwanda',
    league: 'Rwanda Premier League',
    aliases: ['Rayon'],
    region: 'africa',
    isPopular: true,
    popularRank: 11,
  ),
  OnboardingTeam(
    id: 'eg-al-ahly',
    name: 'Al Ahly',
    country: 'Egypt',
    league: 'Egyptian Premier League',
    aliases: ['Ahly'],
    region: 'africa',
    isPopular: true,
    popularRank: 12,
  ),
  OnboardingTeam(
    id: 'za-kaizer-chiefs',
    name: 'Kaizer Chiefs',
    country: 'South Africa',
    league: 'Premier Soccer League',
    aliases: ['Chiefs'],
    region: 'africa',
    isPopular: true,
    popularRank: 13,
  ),
  OnboardingTeam(
    id: 'mt-valletta',
    name: 'Valletta',
    country: 'Malta',
    league: 'Maltese Premier League',
    aliases: ['Valletta FC'],
    region: 'malta',
    isPopular: true,
    popularRank: 14,
  ),
  OnboardingTeam(
    id: 'mt-hamrun-spartans',
    name: 'Hamrun Spartans',
    country: 'Malta',
    league: 'Maltese Premier League',
    aliases: ['Hamrun'],
    region: 'malta',
    isPopular: true,
    popularRank: 15,
  ),
  OnboardingTeam(
    id: 'mt-floriana',
    name: 'Floriana',
    country: 'Malta',
    league: 'Maltese Premier League',
    region: 'malta',
    isPopular: true,
    popularRank: 16,
  ),
  OnboardingTeam(
    id: 'mt-hibernians',
    name: 'Hibernians',
    country: 'Malta',
    league: 'Maltese Premier League',
    region: 'malta',
    isPopular: true,
    popularRank: 17,
  ),
  OnboardingTeam(
    id: 'us-inter-miami',
    name: 'Inter Miami',
    country: 'United States',
    league: 'MLS',
    aliases: ['Miami'],
    region: 'americas',
    isPopular: true,
    popularRank: 18,
  ),
  OnboardingTeam(
    id: 'ar-boca-juniors',
    name: 'Boca Juniors',
    country: 'Argentina',
    league: 'Primera Division',
    aliases: ['Boca'],
    region: 'americas',
    isPopular: true,
    popularRank: 19,
  ),
  OnboardingTeam(
    id: 'br-flamengo',
    name: 'Flamengo',
    country: 'Brazil',
    league: 'Brasileirao',
    region: 'americas',
    isPopular: true,
    popularRank: 20,
  ),
];
