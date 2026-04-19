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
  });

  factory OnboardingTeam.fromJson(Map<String, dynamic> json) {
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
          json['countryCode']?.toString() ??
          json['country_code']?.toString(),
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

  String get shortName {
    final override = shortNameOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    if (aliases.isNotEmpty) return aliases.first;
    if (name.length > 12) {
      final clean = name
          .replaceFirst(RegExp(r'^(FC |AFC |AC |AS |SS |SSC |ACF |VfL |RB )'), '')
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
    return _countryToCode[country] ??
        country.substring(0, country.length >= 2 ? 2 : 1).toUpperCase();
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
  TeamSearchCatalog(this.allTeams)
    : _byId = {for (final team in allTeams) team.id: team};

  factory TeamSearchCatalog.defaults() {
    return TeamSearchCatalog(_defaultTeams);
  }

  factory TeamSearchCatalog.fromRawJson(String raw) {
    final decoded = jsonDecode(raw);
    final payload = decoded is Map<String, dynamic>
        ? (decoded['teams'] as List<dynamic>? ?? const <dynamic>[])
        : decoded as List<dynamic>;

    return TeamSearchCatalog(
      payload
          .whereType<Map>()
          .map((row) => OnboardingTeam.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
    );
  }

  final List<OnboardingTeam> allTeams;
  final Map<String, OnboardingTeam> _byId;

  OnboardingTeam? byId(String teamId) => _byId[teamId];

  List<OnboardingTeam> search(String query, {int limit = 10}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    return allTeams
        .where((team) {
          if (team.name.toLowerCase().contains(normalized)) return true;
          if (team.shortName.toLowerCase().contains(normalized)) return true;
          return team.aliases.any(
            (alias) => alias.toLowerCase().contains(normalized),
          );
        })
        .take(limit)
        .toList(growable: false);
  }

  List<OnboardingTeam> popularForRegion(String region) {
    if (region == 'global') {
      return allTeams
          .where((team) => team.isPopular)
          .toList(growable: false);
    }

    final regional = allTeams
        .where((team) => team.region == region && team.isPopular)
        .toList();
    if (regional.length >= 8) {
      return regional;
    }

    final globalPopular = allTeams
        .where((team) => team.isPopular && !regional.contains(team))
        .take(8 - regional.length)
        .toList();
    return [...regional, ...globalPopular];
  }
}

const List<OnboardingTeam> _defaultTeams = <OnboardingTeam>[
  OnboardingTeam(
    id: 'liverpool',
    name: 'Liverpool',
    country: 'England',
    league: 'Premier League',
    aliases: <String>['LFC', 'Reds'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'LIV',
  ),
  OnboardingTeam(
    id: 'arsenal',
    name: 'Arsenal',
    country: 'England',
    league: 'Premier League',
    aliases: <String>['Gunners'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'ARS',
  ),
  OnboardingTeam(
    id: 'barcelona',
    name: 'Barcelona',
    country: 'Spain',
    league: 'La Liga',
    aliases: <String>['Barca'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'BAR',
  ),
  OnboardingTeam(
    id: 'real-madrid',
    name: 'Real Madrid',
    country: 'Spain',
    league: 'La Liga',
    aliases: <String>['Los Blancos', 'Madrid'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'RMA',
  ),
  OnboardingTeam(
    id: 'manchester-city',
    name: 'Manchester City',
    country: 'England',
    league: 'Premier League',
    aliases: <String>['Man City', 'City'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'MCI',
  ),
  OnboardingTeam(
    id: 'manchester-united',
    name: 'Manchester United',
    country: 'England',
    league: 'Premier League',
    aliases: <String>['Man United', 'United'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'MUN',
  ),
  OnboardingTeam(
    id: 'bayern-munich',
    name: 'Bayern Munich',
    country: 'Germany',
    league: 'Bundesliga',
    aliases: <String>['Bayern'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'BAY',
  ),
  OnboardingTeam(
    id: 'juventus',
    name: 'Juventus',
    country: 'Italy',
    league: 'Serie A',
    aliases: <String>['Juve'],
    region: 'global',
    isPopular: true,
    shortNameOverride: 'JUV',
  ),
  OnboardingTeam(
    id: 'england',
    name: 'England',
    country: 'England',
    league: 'National Team',
    aliases: <String>['Three Lions'],
    region: 'europe',
    isPopular: true,
    shortNameOverride: 'ENG',
  ),
  OnboardingTeam(
    id: 'valletta-fc',
    name: 'Valletta',
    country: 'Malta',
    league: 'Maltese Premier League',
    aliases: <String>['Valletta FC'],
    region: 'malta',
    isPopular: true,
    shortNameOverride: 'VAL',
  ),
  OnboardingTeam(
    id: 'hamrun-spartans',
    name: 'Hamrun Spartans',
    country: 'Malta',
    league: 'Maltese Premier League',
    aliases: <String>['Hamrun'],
    region: 'malta',
    isPopular: true,
    shortNameOverride: 'HAM',
  ),
  OnboardingTeam(
    id: 'birkirkara',
    name: 'Birkirkara',
    country: 'Malta',
    league: 'Maltese Premier League',
    aliases: <String>['Birkirkara FC'],
    region: 'malta',
    isPopular: true,
    shortNameOverride: 'BIR',
  ),
  OnboardingTeam(
    id: 'apr-fc',
    name: 'APR FC',
    country: 'Rwanda',
    league: 'Rwanda Premier League',
    aliases: <String>['APR'],
    region: 'africa',
    isPopular: true,
    shortNameOverride: 'APR',
  ),
  OnboardingTeam(
    id: 'al-ahly',
    name: 'Al Ahly',
    country: 'Egypt',
    league: 'Egyptian Premier League',
    aliases: <String>['Ahly'],
    region: 'africa',
    isPopular: true,
    shortNameOverride: 'AHL',
  ),
  OnboardingTeam(
    id: 'wydad',
    name: 'Wydad Casablanca',
    country: 'Morocco',
    league: 'Botola Pro',
    aliases: <String>['Wydad'],
    region: 'africa',
    isPopular: true,
    shortNameOverride: 'WAC',
  ),
  OnboardingTeam(
    id: 'young-africans',
    name: 'Young Africans',
    country: 'Tanzania',
    league: 'NBC Premier League',
    aliases: <String>['Yanga'],
    region: 'africa',
    isPopular: true,
    shortNameOverride: 'YAN',
  ),
  OnboardingTeam(
    id: 'tp-mazembe',
    name: 'TP Mazembe',
    country: 'DR Congo',
    league: 'Linafoot',
    aliases: <String>['Mazembe'],
    region: 'africa',
    isPopular: true,
    shortNameOverride: 'TPM',
  ),
  OnboardingTeam(
    id: 'flamengo',
    name: 'Flamengo',
    country: 'Brazil',
    league: 'Brasileirao',
    aliases: <String>['Mengao'],
    region: 'americas',
    isPopular: true,
    shortNameOverride: 'FLA',
  ),
  OnboardingTeam(
    id: 'boca-juniors',
    name: 'Boca Juniors',
    country: 'Argentina',
    league: 'Primera Division',
    aliases: <String>['Boca'],
    region: 'americas',
    isPopular: true,
    shortNameOverride: 'BOC',
  ),
  OnboardingTeam(
    id: 'inter-miami',
    name: 'Inter Miami',
    country: 'United States',
    league: 'MLS',
    aliases: <String>['Miami'],
    region: 'americas',
    isPopular: true,
    shortNameOverride: 'MIA',
  ),
];
