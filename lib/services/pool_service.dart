import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show supabaseInitialized;
import '../models/pool.dart';
import '../providers/auth_provider.dart';

part 'pool_service.g.dart';

@riverpod
class PoolService extends _$PoolService {
  @override
  FutureOr<List<ScorePool>> build() async {
    ref.watch(authStateProvider);

    if (!supabaseInitialized) return const [];

    final client = Supabase.instance.client;
    // Let errors propagate — don't mask as empty
    final data = await client
        .from('challenge_feed')
        .select()
        .order('lock_at', ascending: true);

    return (data as List).map((row) {
      return ScorePool(
        id: row['id']?.toString() ?? '',
        matchId: row['match_id']?.toString() ?? '',
        matchName:
            row['match_name']?.toString() ??
            '${row['home_team'] ?? 'Home'} vs ${row['away_team'] ?? 'Away'}',
        creatorId: row['creator_user_id']?.toString() ?? '',
        creatorName: row['creator_name']?.toString() ?? 'Fan',
        creatorPrediction: row['creator_prediction']?.toString() ?? '',
        stake: (row['stake_fet'] as num?)?.toInt() ?? 0,
        totalPool: (row['total_pool_fet'] as num?)?.toInt() ?? 0,
        participantsCount: (row['total_participants'] as num?)?.toInt() ?? 0,
        status: row['status']?.toString() ?? 'open',
        lockAt: row['lock_at'] != null
            ? DateTime.tryParse(row['lock_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
    }).toList();
  }

  /// Create a new score pool via atomic RPC.
  /// Backend also enforces the 5 pools/hour rate limit per user.
  ///
  /// Sets [state] to loading to prevent double-submission from rapid taps.
  Future<void> createPool({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required int stake,
  }) async {
    // Guard: if already loading, reject duplicate calls.
    if (state is AsyncLoading) return;

    if (!supabaseInitialized) {
      throw StateError('Supabase not initialized');
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }

    if (stake < 10) {
      throw ArgumentError('Minimum stake is 10 FET');
    }

    if (homeScore < 0 || awayScore < 0) {
      throw ArgumentError('Scores must be zero or greater');
    }

    // Set loading state so the UI disables the submit button.
    final previous = state;
    state = const AsyncLoading();

    try {
      // Atomic server-side operation: validates, debits wallet,
      // creates pool + entry in a single transaction.
      await client.rpc(
        'create_pool',
        params: {
          'p_match_id': matchId,
          'p_home_score': homeScore,
          'p_away_score': awayScore,
          'p_stake': stake,
        },
      );

      ref.invalidateSelf();
      ref.invalidate(myEntriesProvider);
    } catch (e) {
      // Restore previous state so the user can retry.
      state = previous;
      rethrow;
    }
  }

  /// Join an existing pool via atomic RPC.
  ///
  /// Sets [state] to loading to prevent double-submission from rapid taps.
  Future<void> joinPool({
    required String poolId,
    required int homeScore,
    required int awayScore,
    required int stake,
  }) async {
    // Guard: if already loading, reject duplicate calls.
    if (state is AsyncLoading) return;

    if (!supabaseInitialized) {
      throw StateError('Supabase not initialized');
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }

    if (homeScore < 0 || awayScore < 0) {
      throw ArgumentError('Scores must be zero or greater');
    }

    // Set loading state so the UI disables the submit button.
    final previous = state;
    state = const AsyncLoading();

    try {
      // Atomic server-side operation: validates pool state, checks duplicates,
      // debits wallet, creates entry, updates totals in a single transaction.
      await client.rpc(
        'join_pool',
        params: {
          'p_pool_id': poolId,
          'p_home_score': homeScore,
          'p_away_score': awayScore,
        },
      );

      ref.invalidateSelf();
      ref.invalidate(myEntriesProvider);
    } catch (e) {
      // Restore previous state so the user can retry.
      state = previous;
      rethrow;
    }
  }
}

@riverpod
class MyEntries extends _$MyEntries {
  @override
  FutureOr<List<PoolEntry>> build() async {
    ref.watch(authStateProvider);

    if (!supabaseInitialized) return const [];

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];

    // Let errors propagate — don't mask as empty
    final data = await client
        .from('prediction_challenge_entries')
        .select()
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    return (data as List).map((row) {
      return PoolEntry(
        id: row['id']?.toString() ?? '',
        poolId: row['challenge_id']?.toString() ?? '',
        userId: row['user_id']?.toString() ?? '',
        userName: 'You',
        predictedHomeScore: (row['predicted_home_score'] as num?)?.toInt() ?? 0,
        predictedAwayScore: (row['predicted_away_score'] as num?)?.toInt() ?? 0,
        stake: (row['stake_fet'] as num?)?.toInt() ?? 0,
        status: row['status']?.toString() ?? 'active',
        payout: (row['payout_fet'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}

/// Provider for a single pool by ID — used by PoolDetailScreen.
@riverpod
FutureOr<ScorePool?> poolDetail(Ref ref, String id) async {
  if (!supabaseInitialized) return null;

  final client = Supabase.instance.client;
  final row = await client
      .from('challenge_feed')
      .select()
      .eq('id', id)
      .maybeSingle();

  if (row == null) return null;

  return ScorePool(
    id: row['id']?.toString() ?? '',
    matchId: row['match_id']?.toString() ?? '',
    matchName:
        row['match_name']?.toString() ??
        '${row['home_team'] ?? 'Home'} vs ${row['away_team'] ?? 'Away'}',
    creatorId: row['creator_user_id']?.toString() ?? '',
    creatorName: row['creator_name']?.toString() ?? 'Fan',
    creatorPrediction: row['creator_prediction']?.toString() ?? '',
    stake: (row['stake_fet'] as num?)?.toInt() ?? 0,
    totalPool: (row['total_pool_fet'] as num?)?.toInt() ?? 0,
    participantsCount: (row['total_participants'] as num?)?.toInt() ?? 0,
    status: row['status']?.toString() ?? 'open',
    lockAt: row['lock_at'] != null
        ? DateTime.tryParse(row['lock_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}
