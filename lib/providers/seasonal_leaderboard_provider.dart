import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/leaderboard_season_model.dart';
import 'auth_provider.dart';

// ─── Active Seasons ────────────────────────────────────────────────

/// All active leaderboard seasons.
final activeLeaderboardSeasonsProvider =
    FutureProvider.autoDispose<List<LeaderboardSeason>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('leaderboard_seasons')
      .select()
      .inFilter('status', ['active', 'upcoming'])
      .order('starts_at')
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) =>
          LeaderboardSeason.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

// ─── Season Rankings ───────────────────────────────────────────────

/// Top entries for a specific season (from materialized view for active).
final seasonRankingsProvider = FutureProvider.family
    .autoDispose<List<SeasonLeaderboardEntry>, String>(
        (ref, seasonId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('mv_season_leaderboard')
      .select()
      .eq('season_id', seasonId)
      .order('points', ascending: false)
      .limit(100)
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) =>
          SeasonLeaderboardEntry.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

// ─── User's Season Entry ───────────────────────────────────────────

/// Current user's entry in a specific season.
final userSeasonEntryProvider = FutureProvider.family
    .autoDispose<SeasonLeaderboardEntry?, String>((ref, seasonId) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (client == null || user == null) return null;

  final data = await client
      .from('leaderboard_entries')
      .select()
      .eq('season_id', seasonId)
      .eq('user_id', user.id)
      .maybeSingle()
      .timeout(supabaseTimeout);

  if (data == null) return null;
  return SeasonLeaderboardEntry.fromJson(data);
});

// ─── Completed Seasons (History) ───────────────────────────────────

/// Completed seasons for the history tab.
final completedSeasonsProvider =
    FutureProvider.autoDispose<List<LeaderboardSeason>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('leaderboard_seasons')
      .select()
      .eq('status', 'completed')
      .order('ends_at', ascending: false)
      .limit(20)
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) =>
          LeaderboardSeason.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});
