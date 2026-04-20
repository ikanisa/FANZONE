import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/daily_challenge_model.dart';

abstract interface class DailyChallengeGateway {
  Future<DailyChallenge?> getTodaysDailyChallenge();

  Future<void> submitDailyPrediction({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  });

  Future<DailyChallengeEntry?> getMyDailyEntry({
    required String challengeId,
    required String userId,
  });

  Future<List<DailyChallengeEntry>> getDailyChallengeHistory(String userId);
}

class SupabaseDailyChallengeGateway implements DailyChallengeGateway {
  SupabaseDailyChallengeGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<DailyChallenge?> getTodaysDailyChallenge() async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('daily_challenges')
          .select()
          .eq('status', 'active')
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return DailyChallenge.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load daily challenge: $error');
      return null;
    }
  }

  @override
  Future<void> submitDailyPrediction({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Supabase not connected');
    }

    try {
      await client.rpc(
        'submit_daily_prediction',
        params: {
          'p_challenge_id': challengeId,
          'p_home_score': homeScore,
          'p_away_score': awayScore,
        },
      );
    } catch (error) {
      AppLogger.d('Failed to submit daily prediction: $error');
      rethrow;
    }
  }

  @override
  Future<DailyChallengeEntry?> getMyDailyEntry({
    required String challengeId,
    required String userId,
  }) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('daily_challenge_entries')
          .select()
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) {
        return DailyChallengeEntry.fromJson(Map<String, dynamic>.from(row));
      }
      return null;
    } catch (error) {
      AppLogger.d('Failed to load daily entry: $error');
      return null;
    }
  }

  @override
  Future<List<DailyChallengeEntry>> getDailyChallengeHistory(
    String userId,
  ) async {
    final client = _connection.client;
    if (client == null) return const <DailyChallengeEntry>[];

    try {
      final rows = await client
          .from('daily_challenge_entries')
          .select()
          .eq('user_id', userId)
          .order('submitted_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                DailyChallengeEntry.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load daily challenge history: $error');
      return const <DailyChallengeEntry>[];
    }
  }
}
