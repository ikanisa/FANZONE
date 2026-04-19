import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/match_model.dart';
import '../models/match_odds_model.dart';
import '../models/live_match_event.dart';

/// Provider for matches — fetches from Supabase with filters.
///
/// Returns MatchModel (Freezed DTO) for backward compatibility with existing
/// widget layer. New V2 features should use domain entities via repositories.
final matchesProvider = FutureProvider.family
    .autoDispose<List<MatchModel>, MatchesFilter>((ref, filter) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      var query = client.from('matches').select();
      if (filter.competitionId != null) {
        query = query.eq('competition_id', filter.competitionId!);
      }
      if (filter.status != null) query = query.eq('status', filter.status!);
      if (filter.teamId != null) {
        query = query.or(
          'home_team_id.eq.${filter.teamId},away_team_id.eq.${filter.teamId}',
        );
      }
      if (filter.dateFrom != null) query = query.gte('date', filter.dateFrom!);
      if (filter.dateTo != null) query = query.lte('date', filter.dateTo!);

      final data = await query
          .order('date', ascending: filter.ascending)
          .limit(filter.limit)
          .timeout(supabaseTimeout);

      return (data as List).map((row) => MatchModel.fromJson(row)).toList();
    });

/// Provider for a single match by ID (realtime stream).
final matchDetailProvider = StreamProvider.family
    .autoDispose<MatchModel?, String>((ref, matchId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(null);

      return client
          .from('matches')
          .stream(primaryKey: ['id'])
          .eq('id', matchId)
          .limit(1)
          .map((rows) {
            if (rows.isEmpty) return null;
            return MatchModel.fromJson(
              Map<String, dynamic>.from(rows.first),
            );
          });
    });

/// Provider for matches on a specific date (realtime stream).
final matchesByDateProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, DateTime>((ref, date) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(const []);

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      return client
          .from('matches')
          .stream(primaryKey: ['id'])
          .eq('date', dateStr)
          .order('kickoff_time', ascending: true)
          .limit(150)
          .map((rows) => rows
              .map((row) =>
                  MatchModel.fromJson(Map<String, dynamic>.from(row)))
              .toList());
    });

/// Provider for competition fixtures (realtime stream).
final competitionMatchesProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, String>((ref, competitionId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(const []);

      return client
          .from('matches')
          .stream(primaryKey: ['id'])
          .eq('competition_id', competitionId)
          .order('date', ascending: false)
          .limit(80)
          .map((rows) => rows
              .map((row) =>
                  MatchModel.fromJson(Map<String, dynamic>.from(row)))
              .toList());
    });

/// Provider for team fixtures (realtime stream — merges home + away).
///
/// Supabase `.stream()` only supports one `.eq()` filter, so we open two
/// server-filtered streams and merge client-side. Much more efficient than
/// fetching all 200 matches and filtering in Dart.
final teamMatchesProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, String>((ref, teamId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(const []);

      final homeStream = client
          .from('matches')
          .stream(primaryKey: ['id'])
          .eq('home_team_id', teamId)
          .order('date', ascending: false)
          .limit(40)
          .map((rows) => rows
              .map((row) =>
                  MatchModel.fromJson(Map<String, dynamic>.from(row)))
              .toList());

      final awayStream = client
          .from('matches')
          .stream(primaryKey: ['id'])
          .eq('away_team_id', teamId)
          .order('date', ascending: false)
          .limit(40)
          .map((rows) => rows
              .map((row) =>
                  MatchModel.fromJson(Map<String, dynamic>.from(row)))
              .toList());

      // Combine latest from both streams, deduplicating by ID.
      return homeStream.asyncExpand((homeMatches) {
        return awayStream.map((awayMatches) {
          final deduped = <String, MatchModel>{};
          for (final match in [...homeMatches, ...awayMatches]) {
            deduped[match.id] = match;
          }
          final merged = deduped.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          return merged.take(40).toList();
        });
      });
    });


/// Filter parameters for matches provider.
class MatchesFilter {
  final String? competitionId;
  final String? status;
  final String? teamId;
  final String? dateFrom;
  final String? dateTo;
  final int limit;
  final bool ascending;

  const MatchesFilter({
    this.competitionId,
    this.status,
    this.teamId,
    this.dateFrom,
    this.dateTo,
    this.limit = 100,
    this.ascending = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchesFilter &&
          competitionId == other.competitionId &&
          status == other.status &&
          teamId == other.teamId &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo &&
          limit == other.limit &&
          ascending == other.ascending;

  @override
  int get hashCode => Object.hash(
    competitionId,
    status,
    teamId,
    dateFrom,
    dateTo,
    limit,
    ascending,
  );
}

/// Realtime Stream Provider for live match events.
final liveMatchEventsStreamProvider = StreamProvider.family
    .autoDispose<List<LiveMatchEvent>, String>((ref, matchId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value([]);

      return client
          .from('live_match_events')
          .stream(primaryKey: ['id'])
          .eq('match_id', matchId)
          .order('minute', ascending: false)
          .map(
            (data) =>
                data.map((json) => LiveMatchEvent.fromJson(json)).toList(),
          );
    });

/// Match odds stream.
final matchOddsProvider = StreamProvider.family
    .autoDispose<MatchOddsModel?, String>((ref, matchId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(null);

      return client
          .from('match_odds_cache')
          .stream(primaryKey: ['match_id'])
          .eq('match_id', matchId)
          .limit(1)
          .map((rows) {
            if (rows.isEmpty) return null;
            return MatchOddsModel.fromJson(
              Map<String, dynamic>.from(rows.first),
            );
          });
    });
