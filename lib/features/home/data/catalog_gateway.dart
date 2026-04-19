import 'package:injectable/injectable.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/competition_model.dart';
import '../../../models/featured_event_model.dart';
import '../../../models/global_challenge_model.dart';
import '../../../models/search_result_model.dart';
import '../../../models/standing_row_model.dart';
import '../../../models/team_model.dart';
import 'home_dtos.dart';

abstract interface class CatalogGateway {
  Future<List<CompetitionModel>> getCompetitions({
    int? tier,
    bool featuredOnly,
  });

  Future<CompetitionModel?> getCompetition(String competitionId);

  Future<List<TeamModel>> getTeams({String? competitionId, bool featuredOnly});

  Future<TeamModel?> getTeam(String teamId);

  Future<SearchResults> search(SearchQueryDto query);

  Future<List<FeaturedEventModel>> getFeaturedEvents({
    bool activeOnly,
    bool upcomingOnly,
    int? limit,
  });

  Future<FeaturedEventModel?> getFeaturedEventByTag(String eventTag);

  Future<List<GlobalChallengeModel>> getGlobalChallenges({
    String? eventTag,
    List<String>? regionValues,
    int? limit,
  });

  Future<List<StandingRowModel>> getCompetitionStandings(
    CompetitionStandingsFilter filter,
  );
}

@LazySingleton(as: CatalogGateway)
class SupabaseCatalogGateway implements CatalogGateway {
  SupabaseCatalogGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<CompetitionModel>> getCompetitions({
    int? tier,
    bool featuredOnly = false,
  }) async {
    final fallback = _filterCompetitions(
      _fallbackCompetitions,
      tier: tier,
      featuredOnly: featuredOnly,
    );
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final rows = await client.from('competitions').select();
      final competitions = (rows as List)
          .whereType<Map>()
          .map(
            (row) => CompetitionModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);

      final filtered = _filterCompetitions(
        competitions,
        tier: tier,
        featuredOnly: featuredOnly,
      );
      return filtered.isEmpty ? fallback : filtered;
    } catch (error) {
      AppLogger.d('Failed to load competitions: $error');
      return fallback;
    }
  }

  @override
  Future<CompetitionModel?> getCompetition(String competitionId) async {
    final competitions = await getCompetitions();
    for (final competition in competitions) {
      if (competition.id == competitionId) return competition;
    }
    return null;
  }

  @override
  Future<List<TeamModel>> getTeams({
    String? competitionId,
    bool featuredOnly = false,
  }) async {
    final fallback = _filterTeams(
      _fallbackTeams,
      competitionId: competitionId,
      featuredOnly: featuredOnly,
    );
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final rows = await client.from('teams').select();
      final teams = (rows as List)
          .whereType<Map>()
          .map((row) => TeamModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      final filtered = _filterTeams(
        teams,
        competitionId: competitionId,
        featuredOnly: featuredOnly,
      );
      return filtered.isEmpty ? fallback : filtered;
    } catch (error) {
      AppLogger.d('Failed to load teams: $error');
      return fallback;
    }
  }

  @override
  Future<TeamModel?> getTeam(String teamId) async {
    final teams = await getTeams();
    for (final team in teams) {
      if (team.id == teamId) return team;
    }
    return null;
  }

  @override
  Future<SearchResults> search(SearchQueryDto query) async {
    final normalized = query.value.trim().toLowerCase();
    if (normalized.isEmpty) return const SearchResults();

    final competitions = await getCompetitions();
    final teams = await getTeams();

    final competitionResults = competitions
        .where((competition) {
          final haystack =
              '${competition.name} ${competition.shortName} ${competition.country}'
                  .toLowerCase();
          return haystack.contains(normalized);
        })
        .map(
          (competition) => SearchResultModel(
            type: SearchResultType.competition,
            id: competition.id,
            title: competition.name,
            subtitle: competition.country,
          ),
        )
        .toList(growable: false);

    final teamResults = teams
        .where((team) {
          final haystack =
              '${team.name} ${team.shortName ?? ''} ${team.country ?? ''} ${team.leagueName ?? ''} ${team.aliases.join(' ')}'
                  .toLowerCase();
          return haystack.contains(normalized);
        })
        .map(
          (team) => SearchResultModel(
            type: SearchResultType.team,
            id: team.id,
            title: team.name,
            subtitle: team.leagueName ?? team.country ?? 'Club',
          ),
        )
        .toList(growable: false);

    return SearchResults(competitions: competitionResults, teams: teamResults);
  }

  @override
  Future<List<FeaturedEventModel>> getFeaturedEvents({
    bool activeOnly = false,
    bool upcomingOnly = false,
    int? limit,
  }) async {
    final fallback = _filterEvents(
      _fallbackEvents(),
      activeOnly: activeOnly,
      upcomingOnly: upcomingOnly,
      limit: limit,
    );
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final rows = await client.from('featured_events').select();
      final events = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                FeaturedEventModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      final filtered = _filterEvents(
        events,
        activeOnly: activeOnly,
        upcomingOnly: upcomingOnly,
        limit: limit,
      );
      return filtered.isEmpty ? fallback : filtered;
    } catch (error) {
      AppLogger.d('Failed to load featured events: $error');
      return fallback;
    }
  }

  @override
  Future<FeaturedEventModel?> getFeaturedEventByTag(String eventTag) async {
    final events = await getFeaturedEvents();
    for (final event in events) {
      if (event.eventTag == eventTag) return event;
    }
    return null;
  }

  @override
  Future<List<GlobalChallengeModel>> getGlobalChallenges({
    String? eventTag,
    List<String>? regionValues,
    int? limit,
  }) async {
    final fallback = _filterChallenges(
      _fallbackChallenges(),
      eventTag: eventTag,
      regionValues: regionValues,
      limit: limit,
    );
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final rows = await client.from('global_challenges').select();
      final challenges = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                GlobalChallengeModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      final filtered = _filterChallenges(
        challenges,
        eventTag: eventTag,
        regionValues: regionValues,
        limit: limit,
      );
      return filtered.isEmpty ? fallback : filtered;
    } catch (error) {
      AppLogger.d('Failed to load global challenges: $error');
      return fallback;
    }
  }

  @override
  Future<List<StandingRowModel>> getCompetitionStandings(
    CompetitionStandingsFilter filter,
  ) async {
    final fallback = _fallbackStandings(filter.competitionId);
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      var query = client
          .from('competition_standings')
          .select()
          .eq('competition_id', filter.competitionId);
      if (filter.season != null && filter.season!.trim().isNotEmpty) {
        query = query.eq('season', filter.season!.trim());
      }
      final rows = await query.order('position');
      final standings = (rows as List)
          .whereType<Map>()
          .map(
            (row) => StandingRowModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return standings.isEmpty ? fallback : standings;
    } catch (error) {
      AppLogger.d('Failed to load standings: $error');
      return fallback;
    }
  }
}

List<CompetitionModel> _filterCompetitions(
  List<CompetitionModel> competitions, {
  int? tier,
  required bool featuredOnly,
}) {
  var filtered = competitions;
  if (tier != null) {
    filtered = filtered
        .where((competition) => competition.tier == tier)
        .toList(growable: false);
  }
  if (featuredOnly) {
    filtered = filtered
        .where((competition) => competition.isFeatured)
        .toList(growable: false);
  }

  return [...filtered]..sort((left, right) => left.name.compareTo(right.name));
}

List<TeamModel> _filterTeams(
  List<TeamModel> teams, {
  String? competitionId,
  required bool featuredOnly,
}) {
  var filtered = teams;
  if (competitionId != null && competitionId.isNotEmpty) {
    filtered = filtered
        .where((team) => team.competitionIds.contains(competitionId))
        .toList(growable: false);
  }
  if (featuredOnly) {
    filtered = filtered
        .where((team) => team.isFeatured)
        .toList(growable: false);
  }

  return [...filtered]..sort((left, right) => left.name.compareTo(right.name));
}

List<FeaturedEventModel> _filterEvents(
  List<FeaturedEventModel> events, {
  required bool activeOnly,
  required bool upcomingOnly,
  int? limit,
}) {
  final now = DateTime.now();
  var filtered = events
      .where((event) {
        if (activeOnly) {
          return event.isActive &&
              !event.startDate.isAfter(now) &&
              !event.endDate.isBefore(now);
        }
        if (upcomingOnly) {
          return event.startDate.isAfter(now);
        }
        return true;
      })
      .toList(growable: false)
    ..sort((left, right) => left.startDate.compareTo(right.startDate));

  if (limit != null && filtered.length > limit) {
    filtered = filtered.take(limit).toList(growable: false);
  }
  return filtered;
}

List<GlobalChallengeModel> _filterChallenges(
  List<GlobalChallengeModel> challenges, {
  String? eventTag,
  List<String>? regionValues,
  int? limit,
}) {
  final normalizedRegions = (regionValues ?? const <String>[])
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();

  var filtered = challenges
      .where((challenge) {
        if (eventTag != null &&
            eventTag.isNotEmpty &&
            challenge.eventTag != eventTag) {
          return false;
        }
        if (normalizedRegions.isNotEmpty &&
            !normalizedRegions.contains(challenge.region.toLowerCase()) &&
            challenge.region.toLowerCase() != 'global') {
          return false;
        }
        return true;
      })
      .toList(growable: false)
    ..sort((left, right) => left.name.compareTo(right.name));

  if (limit != null && filtered.length > limit) {
    filtered = filtered.take(limit).toList(growable: false);
  }
  return filtered;
}

List<StandingRowModel> _fallbackStandings(String competitionId) {
  switch (competitionId) {
    case 'epl':
      return const [
        StandingRowModel(
          competitionId: 'epl',
          season: '2025/26',
          teamId: 'liverpool',
          teamName: 'Liverpool',
          position: 1,
          played: 28,
          won: 20,
          drawn: 5,
          lost: 3,
          goalsFor: 61,
          goalsAgainst: 25,
          goalDifference: 36,
          points: 65,
        ),
        StandingRowModel(
          competitionId: 'epl',
          season: '2025/26',
          teamId: 'arsenal',
          teamName: 'Arsenal',
          position: 2,
          played: 28,
          won: 18,
          drawn: 6,
          lost: 4,
          goalsFor: 57,
          goalsAgainst: 27,
          goalDifference: 30,
          points: 60,
        ),
      ];
    case 'laliga':
      return const [
        StandingRowModel(
          competitionId: 'laliga',
          season: '2025/26',
          teamId: 'barcelona',
          teamName: 'Barcelona',
          position: 1,
          played: 28,
          won: 19,
          drawn: 4,
          lost: 5,
          goalsFor: 63,
          goalsAgainst: 29,
          goalDifference: 34,
          points: 61,
        ),
        StandingRowModel(
          competitionId: 'laliga',
          season: '2025/26',
          teamId: 'real-madrid',
          teamName: 'Real Madrid',
          position: 2,
          played: 28,
          won: 18,
          drawn: 5,
          lost: 5,
          goalsFor: 59,
          goalsAgainst: 31,
          goalDifference: 28,
          points: 59,
        ),
      ];
    default:
      return const [];
  }
}

List<FeaturedEventModel> _fallbackEvents() {
  final now = DateTime.now();
  return [
    FeaturedEventModel(
      id: 'world-cup-2026',
      name: 'World Cup 2026',
      shortName: 'World Cup',
      eventTag: 'worldcup2026',
      region: 'global',
      competitionId: 'world-cup',
      startDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 3)),
      endDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 21)),
      isActive: true,
      bannerColor: '#22D3EE',
      description: 'Global matchday spotlight with featured predictions.',
    ),
    FeaturedEventModel(
      id: 'ucl-final-2026',
      name: 'UCL Final 2026',
      shortName: 'UCL Final',
      eventTag: 'ucl-final-2026',
      region: 'europe',
      competitionId: 'ucl',
      startDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 10)),
      endDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 12)),
      isActive: true,
      bannerColor: '#2563EB',
      description:
          'Countdown coverage for the biggest club final of the season.',
    ),
  ];
}

List<GlobalChallengeModel> _fallbackChallenges() {
  final now = DateTime.now();
  return [
    GlobalChallengeModel(
      id: 'challenge-global-1',
      eventTag: 'worldcup2026',
      name: 'World Cup Matchday Challenge',
      description: 'Predict the featured fixtures and climb the launch ladder.',
      matchIds: const ['match_live_1', 'match_upcoming_1'],
      entryFeeFet: 0,
      prizePoolFet: 2000,
      currentParticipants: 128,
      region: 'global',
      status: 'open',
      startAt: now.subtract(const Duration(days: 1)),
      endAt: now.add(const Duration(days: 6)),
    ),
  ];
}

const List<CompetitionModel> _fallbackCompetitions = <CompetitionModel>[
  CompetitionModel(
    id: 'epl',
    name: 'Premier League',
    shortName: 'EPL',
    country: 'England',
    tier: 1,
    dataSource: 'fallback',
    seasons: ['2025/26'],
    teamCount: 20,
    isFeatured: true,
  ),
  CompetitionModel(
    id: 'laliga',
    name: 'La Liga',
    shortName: 'LALIGA',
    country: 'Spain',
    tier: 1,
    dataSource: 'fallback',
    seasons: ['2025/26'],
    teamCount: 20,
    isFeatured: true,
  ),
  CompetitionModel(
    id: 'ucl',
    name: 'UEFA Champions League',
    shortName: 'UCL',
    country: 'Europe',
    tier: 1,
    dataSource: 'fallback',
    seasons: ['2025/26'],
    teamCount: 36,
    isFeatured: true,
    eventTag: 'ucl-final-2026',
  ),
];

const List<TeamModel> _fallbackTeams = <TeamModel>[
  TeamModel(
    id: 'liverpool',
    name: 'Liverpool',
    shortName: 'LIV',
    country: 'England',
    leagueName: 'Premier League',
    competitionIds: ['epl'],
    aliases: ['LFC', 'Reds'],
    isFeatured: true,
    fanCount: 24000,
  ),
  TeamModel(
    id: 'arsenal',
    name: 'Arsenal',
    shortName: 'ARS',
    country: 'England',
    leagueName: 'Premier League',
    competitionIds: ['epl'],
    aliases: ['Gunners'],
    isFeatured: true,
    fanCount: 22000,
  ),
  TeamModel(
    id: 'barcelona',
    name: 'Barcelona',
    shortName: 'BAR',
    country: 'Spain',
    leagueName: 'La Liga',
    competitionIds: ['laliga'],
    aliases: ['Barca'],
    isFeatured: true,
    fanCount: 26000,
  ),
  TeamModel(
    id: 'real-madrid',
    name: 'Real Madrid',
    shortName: 'RMA',
    country: 'Spain',
    leagueName: 'La Liga',
    competitionIds: ['laliga'],
    aliases: ['Los Blancos'],
    isFeatured: true,
    fanCount: 25500,
  ),
  TeamModel(
    id: 'manchester-city',
    name: 'Manchester City',
    shortName: 'MCI',
    country: 'England',
    leagueName: 'Premier League',
    competitionIds: ['epl'],
    aliases: ['City'],
    fanCount: 21000,
  ),
  TeamModel(
    id: 'manchester-united',
    name: 'Manchester United',
    shortName: 'MUN',
    country: 'England',
    leagueName: 'Premier League',
    competitionIds: ['epl'],
    aliases: ['United'],
    fanCount: 23500,
  ),
];
