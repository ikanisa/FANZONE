import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../data/team_search_database.dart';
import '../features/home/data/home_match_curator.dart';
import '../models/match_model.dart';
import 'favorite_teams_provider.dart';
import 'matches_provider.dart';

final homeDefaultTeamsProvider =
    FutureProvider.autoDispose<List<OnboardingTeam>>((ref) async {
      return _loadHomeDefaultTeams(ref);
    });

final homeFeedMatchesProvider = FutureProvider.family
    .autoDispose<HomeFeedSelection, MatchesFilter>((ref, filter) async {
      final matches = await ref.watch(matchesProvider(filter).future);
      final favoriteTeams = await _loadFavoriteTeams(ref);
      final overrides = await _fetchHomeDisplayOverrides(ref, matches);
      final defaultHomeTeams = await ref.watch(homeDefaultTeamsProvider.future);

      final primarySelection = curateHomeFeedMatches(
        matches: matches,
        defaultHomeTeams: defaultHomeTeams,
        favoriteTeams: favoriteTeams,
        overrides: overrides,
      );

      if (primarySelection.liveMatches.isNotEmpty ||
          primarySelection.upcomingMatches.isNotEmpty ||
          !matches.any((match) => match.isLive || match.isUpcoming)) {
        return primarySelection;
      }
      return primarySelection;
    });

Future<List<FavoriteTeamRecordDto>> _loadFavoriteTeams(Ref ref) async {
  try {
    return await ref.watch(favoriteTeamRecordsProvider.future);
  } catch (_) {
    return const <FavoriteTeamRecordDto>[];
  }
}

Future<List<OnboardingTeam>> _loadHomeDefaultTeams(Ref ref) async {
  return _loadTopEuropeanHomeTeams(ref);
}

Future<List<OnboardingTeam>> _loadTopEuropeanHomeTeams(Ref ref) async {
  final client = ref.read(supabaseConnectionProvider).client;
  if (client == null) return const <OnboardingTeam>[];

  try {
    final rows = await client
        .from('teams')
        .select(
          'id, name, short_name, aliases, search_terms, country, country_code, region, league_name, logo_url, crest_url, is_featured, is_popular_pick, popular_pick_rank, is_active',
        )
        .eq('is_active', true)
        .eq('region', 'europe')
        .eq('is_popular_pick', true)
        .order('popular_pick_rank', ascending: true)
        .range(0, kDefaultHomeFeaturedClubLimit - 1);

    final teams = (rows as List)
        .whereType<Map>()
        .map(_popularTeamRowToOnboardingTeam)
        .whereType<OnboardingTeam>()
        .toList(growable: false);
    if (teams.isEmpty) return const <OnboardingTeam>[];

    return teams.take(kDefaultHomeFeaturedClubLimit).toList(growable: false);
  } catch (_) {
    return const <OnboardingTeam>[];
  }
}

OnboardingTeam? _popularTeamRowToOnboardingTeam(Map row) {
  final id = row['id']?.toString();
  final name = row['name']?.toString();
  if (id == null || id.isEmpty || name == null || name.isEmpty) return null;

  final aliases = <String>[
    ...(row['aliases'] as List<dynamic>? ?? const <dynamic>[]).map(
      (value) => value.toString(),
    ),
    ...(row['search_terms'] as List<dynamic>? ?? const <dynamic>[]).map(
      (value) => value.toString(),
    ),
  ].where((value) => value.trim().isNotEmpty).toSet().toList(growable: false);

  return OnboardingTeam(
    id: id,
    name: name,
    country: row['country']?.toString() ?? '',
    league: row['league_name']?.toString(),
    aliases: aliases,
    region: row['region']?.toString() ?? 'global',
    isPopular:
        row['is_popular_pick'] == true ||
        row['is_featured'] == true ||
        (row['popular_pick_rank'] as num?) != null,
    shortNameOverride: row['short_name']?.toString(),
    crestUrl: row['crest_url']?.toString().trim().isNotEmpty == true
        ? row['crest_url']?.toString()
        : row['logo_url']?.toString(),
    countryCodeOverride: row['country_code']?.toString(),
    popularRank: (row['popular_pick_rank'] as num?)?.toInt(),
  );
}

Future<Map<String, MatchHomeDisplayOverride>> _fetchHomeDisplayOverrides(
  Ref ref,
  List<MatchModel> matches,
) async {
  final client = ref.read(supabaseConnectionProvider).client;
  if (client == null || matches.isEmpty) {
    return const <String, MatchHomeDisplayOverride>{};
  }

  final matchIds = matches
      .map((match) => match.id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (matchIds.isEmpty) return const <String, MatchHomeDisplayOverride>{};

  try {
    final rows = await client
        .from('matches')
        .select('id, is_home_featured, hide_from_home, home_feature_rank')
        .inFilter('id', matchIds);

    final overrides = <String, MatchHomeDisplayOverride>{};
    for (final row in (rows as List).whereType<Map>()) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;

      overrides[id] = MatchHomeDisplayOverride(
        isHomeFeatured: row['is_home_featured'] == true,
        hideFromHome: row['hide_from_home'] == true,
        homeFeatureRank: (row['home_feature_rank'] as num?)?.toInt() ?? 0,
      );
    }
    return overrides;
  } catch (_) {
    return const <String, MatchHomeDisplayOverride>{};
  }
}
