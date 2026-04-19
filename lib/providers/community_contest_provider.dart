import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/community_contest_model.dart';
import 'auth_provider.dart';

// ─── Open Contests ─────────────────────────────────────────────────

/// All open community contests.
final openContestsProvider =
    FutureProvider.autoDispose<List<CommunityContest>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('community_contests')
      .select()
      .eq('status', 'open')
      .order('created_at', ascending: false)
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) =>
          CommunityContest.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

// ─── Contest By Match ──────────────────────────────────────────────

/// Contest for a specific match (if one exists).
final contestForMatchProvider = FutureProvider.family
    .autoDispose<CommunityContest?, String>((ref, matchId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;

  final data = await client
      .from('community_contests')
      .select()
      .eq('match_id', matchId)
      .maybeSingle()
      .timeout(supabaseTimeout);

  if (data == null) return null;
  return CommunityContest.fromJson(data);
});

// ─── Contest Entries ────────────────────────────────────────────────

/// All entries for a contest.
final contestEntriesProvider = FutureProvider.family
    .autoDispose<List<ContestEntry>, String>((ref, contestId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('community_contest_entries')
      .select()
      .eq('contest_id', contestId)
      .order('accuracy_score', ascending: false)
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) =>
          ContestEntry.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

// ─── User Contest Entry ────────────────────────────────────────────

/// Current user's entry in a contest (if submitted).
final userContestEntryProvider = FutureProvider.family
    .autoDispose<ContestEntry?, String>((ref, contestId) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (client == null || user == null) return null;

  final data = await client
      .from('community_contest_entries')
      .select()
      .eq('contest_id', contestId)
      .eq('user_id', user.id)
      .maybeSingle()
      .timeout(supabaseTimeout);

  if (data == null) return null;
  return ContestEntry.fromJson(data);
});

// ─── Settled Contests (History) ────────────────────────────────────

/// Recently settled contests.
final settledContestsProvider =
    FutureProvider.autoDispose<List<CommunityContest>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('community_contests')
      .select()
      .eq('status', 'settled')
      .order('settled_at', ascending: false)
      .limit(20)
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) =>
          CommunityContest.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});
