import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show supabaseInitialized;
import '../providers/auth_provider.dart';
import '../models/daily_challenge_model.dart';

part 'daily_challenge_service.g.dart';

/// Service for daily free prediction challenges.
@riverpod
class DailyChallengeService extends _$DailyChallengeService {
  @override
  FutureOr<DailyChallenge?> build() async {
    ref.watch(authStateProvider);

    if (!supabaseInitialized) return null;

    final client = Supabase.instance.client;

    // Get today's challenge
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await client
        .from('daily_challenges')
        .select()
        .eq('date', today)
        .eq('status', 'active')
        .maybeSingle();

    if (data == null) return null;

    return DailyChallenge(
      id: data['id']?.toString() ?? '',
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
      matchId: data['match_id']?.toString() ?? '',
      matchName: data['match_name']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Daily Challenge',
      description: data['description']?.toString() ?? '',
      rewardFet: (data['reward_fet'] as num?)?.toInt() ?? 50,
      bonusExactFet: (data['bonus_exact_fet'] as num?)?.toInt() ?? 200,
      status: data['status']?.toString() ?? 'active',
      officialHomeScore: (data['official_home_score'] as num?)?.toInt(),
      officialAwayScore: (data['official_away_score'] as num?)?.toInt(),
      totalEntries: (data['total_entries'] as num?)?.toInt() ?? 0,
      totalWinners: (data['total_winners'] as num?)?.toInt() ?? 0,
    );
  }

  /// Submit a prediction for today's daily challenge.
  Future<void> submitPrediction({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    if (!supabaseInitialized) {
      throw StateError('Supabase not initialized');
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Not authenticated');
    }

    await client.rpc(
      'submit_daily_prediction',
      params: {
        'p_challenge_id': challengeId,
        'p_home_score': homeScore,
        'p_away_score': awayScore,
      },
    );

    ref.invalidateSelf();
    ref.invalidate(myDailyEntryProvider);
    ref.invalidate(dailyChallengeHistoryProvider);
  }
}

/// Provider for the user's entry in today's challenge.
@riverpod
FutureOr<DailyChallengeEntry?> myDailyEntry(Ref ref) async {
  ref.watch(authStateProvider);

  if (!supabaseInitialized) return null;

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final challenge = await ref.watch(dailyChallengeServiceProvider.future);
  if (challenge == null) return null;

  final data = await client
      .from('daily_challenge_entries')
      .select()
      .eq('challenge_id', challenge.id)
      .eq('user_id', userId)
      .maybeSingle();

  if (data == null) return null;

  return DailyChallengeEntry(
    id: data['id']?.toString() ?? '',
    challengeId: data['challenge_id']?.toString() ?? '',
    userId: data['user_id']?.toString() ?? '',
    predictedHomeScore: (data['predicted_home_score'] as num?)?.toInt() ?? 0,
    predictedAwayScore: (data['predicted_away_score'] as num?)?.toInt() ?? 0,
    result: data['result']?.toString() ?? 'pending',
    payoutFet: (data['payout_fet'] as num?)?.toInt() ?? 0,
    submittedAt: data['submitted_at'] != null
        ? DateTime.tryParse(data['submitted_at'].toString())
        : null,
  );
}

/// Provider for user's daily challenge history (last 30 days).
@riverpod
FutureOr<List<DailyChallengeEntry>> dailyChallengeHistory(Ref ref) async {
  ref.watch(authStateProvider);

  if (!supabaseInitialized) return const [];

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  final data = await client
      .from('daily_challenge_entries')
      .select()
      .eq('user_id', userId)
      .order('submitted_at', ascending: false)
      .limit(30);

  return (data as List)
      .map(
        (row) => DailyChallengeEntry(
          id: row['id']?.toString() ?? '',
          challengeId: row['challenge_id']?.toString() ?? '',
          userId: row['user_id']?.toString() ?? '',
          predictedHomeScore:
              (row['predicted_home_score'] as num?)?.toInt() ?? 0,
          predictedAwayScore:
              (row['predicted_away_score'] as num?)?.toInt() ?? 0,
          result: row['result']?.toString() ?? 'pending',
          payoutFet: (row['payout_fet'] as num?)?.toInt() ?? 0,
          submittedAt: row['submitted_at'] != null
              ? DateTime.tryParse(row['submitted_at'].toString())
              : null,
        ),
      )
      .toList();
}
