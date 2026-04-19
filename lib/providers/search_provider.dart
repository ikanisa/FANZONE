import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../core/utils/extensions.dart';
import '../models/search_result_model.dart';
import '../models/match_model.dart';

/// Search provider — queries Supabase directly via client provider.
/// No longer depends on SupabaseService.
final searchProvider = FutureProvider.family.autoDispose<SearchResults, String>(
  (ref, rawQuery) async {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return const SearchResults();

    final query = rawQuery.sanitisedForSearch;
    if (query.isEmpty) return const SearchResults();

    final competitionFuture = client
        .from('competitions')
        .select('id, name, short_name, country')
        .or('name.ilike.%$query%,short_name.ilike.%$query%,country.ilike.%$query%')
        .order('tier')
        .limit(6);

    final teamFuture = client
        .from('teams')
        .select('id, name, short_name, country')
        .or('name.ilike.%$query%,short_name.ilike.%$query%,country.ilike.%$query%')
        .order('name')
        .limit(8);

    final matchFuture = client
        .from('matches')
        .select()
        .or('home_team.ilike.%$query%,away_team.ilike.%$query%')
        .order('date', ascending: false)
        .limit(8);

    final responses = await Future.wait([
      competitionFuture,
      teamFuture,
      matchFuture,
    ]).timeout(supabaseTimeout);

    final competitions = (responses[0] as List).map((row) => SearchResultModel(
      type: SearchResultType.competition,
      id: row['id'] as String,
      title: row['name'] as String? ?? 'Competition',
      subtitle: row['country'] as String? ?? row['short_name'] as String? ?? '',
    )).toList();

    final teams = (responses[1] as List).map((row) => SearchResultModel(
      type: SearchResultType.team,
      id: row['id'] as String,
      title: row['name'] as String? ?? 'Team',
      subtitle: row['country'] as String? ?? row['short_name'] as String? ?? '',
    )).toList();

    final matches = (responses[2] as List).map((row) {
      final m = MatchModel.fromJson(row);
      return searchResultFromMatch(m);
    }).toList();

    return SearchResults(
      competitions: competitions,
      teams: teams,
      matches: matches,
    );
  },
);
