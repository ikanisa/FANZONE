import '../../../config/app_config.dart';
import '../../../models/competition_model.dart';
import '../../../models/featured_event_model.dart';
import '../../../models/global_challenge_model.dart';
import '../../../models/standing_row_model.dart';
import '../../../models/team_model.dart';

/// Fallback seed data is only served in development builds.
/// In production, empty lists trigger proper empty-state UIs.
bool get _allowCatalogFallback => AppConfig.isDevelopment;

List<CompetitionModel> filterCompetitions(
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

List<TeamModel> filterTeams(
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

List<FeaturedEventModel> filterEvents(
  List<FeaturedEventModel> events, {
  required bool activeOnly,
  required bool upcomingOnly,
  int? limit,
}) {
  final now = DateTime.now();
  var filtered =
      events
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

List<GlobalChallengeModel> filterChallenges(
  List<GlobalChallengeModel> challenges, {
  String? eventTag,
  List<String>? regionValues,
  int? limit,
}) {
  final normalizedRegions = (regionValues ?? const <String>[])
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();

  var filtered =
      challenges
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

List<StandingRowModel> fallbackStandings(String competitionId) {
  if (!_allowCatalogFallback) return const [];
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

List<FeaturedEventModel> fallbackEvents() {
  if (!_allowCatalogFallback) return const [];
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
      bannerColor: '#98FF98',
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

List<GlobalChallengeModel> fallbackChallenges() {
  if (!_allowCatalogFallback) return const [];
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

/// Fallback competitions — dev-only. Returns empty in production.
List<CompetitionModel> get fallbackCompetitions =>
    _allowCatalogFallback ? _devFallbackCompetitions : const [];

const List<CompetitionModel> _devFallbackCompetitions = <CompetitionModel>[
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

/// Fallback teams — dev-only. Returns empty in production.
List<TeamModel> get fallbackTeams =>
    _allowCatalogFallback ? _devFallbackTeams : const [];

const List<TeamModel> _devFallbackTeams = <TeamModel>[
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
