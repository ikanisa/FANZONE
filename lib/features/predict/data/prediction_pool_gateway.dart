import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/pool.dart';
import 'predict_gateway_models.dart';

abstract interface class PredictionPoolGateway {
  Future<List<ScorePool>> getPools();

  Future<String> createPool(PoolCreateRequestDto request);

  Future<void> joinPool(PoolJoinRequestDto request);

  Future<List<PoolEntry>> getMyEntries(String userId);

  Future<ScorePool?> getPoolDetail(String id);
}

class SupabasePredictionPoolGateway implements PredictionPoolGateway {
  SupabasePredictionPoolGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<ScorePool>> getPools() async {
    final client = _connection.client;
    if (client == null) return const <ScorePool>[];

    try {
      final rows = await client
          .from('prediction_challenges')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .whereType<Map>()
          .map((row) => _poolFromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load pools: $error');
      return const <ScorePool>[];
    }
  }

  @override
  Future<String> createPool(PoolCreateRequestDto request) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Supabase not connected');
    }

    try {
      final result = await client.rpc(
        'create_pool_rate_limited',
        params: {
          'p_match_id': request.matchId,
          'p_home_score': request.homeScore,
          'p_away_score': request.awayScore,
          'p_stake': request.stake,
        },
      );
      final payload = result is Map
          ? Map<String, dynamic>.from(result)
          : const <String, dynamic>{};
      final poolId = payload['pool_id']?.toString();
      if (poolId == null || poolId.isEmpty) {
        throw StateError('Pool created but no pool id was returned');
      }
      return poolId;
    } catch (error) {
      AppLogger.d('Failed to create pool: $error');
      rethrow;
    }
  }

  @override
  Future<void> joinPool(PoolJoinRequestDto request) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Supabase not connected');
    }

    try {
      await client.rpc(
        'join_pool',
        params: {
          'p_pool_id': request.poolId,
          'p_home_score': request.homeScore,
          'p_away_score': request.awayScore,
        },
      );
    } catch (error) {
      AppLogger.d('Failed to join pool: $error');
      rethrow;
    }
  }

  @override
  Future<List<PoolEntry>> getMyEntries(String userId) async {
    final client = _connection.client;
    if (client == null) return const <PoolEntry>[];

    try {
      final rows = await client
          .from('prediction_challenge_entries')
          .select()
          .eq('user_id', userId)
          .order('joined_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map((row) => _poolEntryFromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load pool entries: $error');
      return const <PoolEntry>[];
    }
  }

  @override
  Future<ScorePool?> getPoolDetail(String id) async {
    final pools = await getPools();
    for (final pool in pools) {
      if (pool.id == id) return pool;
    }
    return null;
  }

  ScorePool _poolFromRow(Map<String, dynamic> row) {
    return ScorePool(
      id: row['id']?.toString() ?? '',
      matchId: row['match_id']?.toString() ?? '',
      matchName: row['match_name']?.toString().trim().isNotEmpty == true
          ? row['match_name'].toString()
          : 'Match pool',
      creatorId: row['creator_user_id']?.toString() ?? '',
      creatorName: 'Fan',
      creatorPrediction:
          row['official_home_score'] != null &&
              row['official_away_score'] != null
          ? '${row['official_home_score']}-${row['official_away_score']}'
          : 'Pending',
      stake: (row['stake_fet'] as num?)?.toInt() ?? 0,
      totalPool: (row['total_pool_fet'] as num?)?.toInt() ?? 0,
      participantsCount: (row['total_participants'] as num?)?.toInt() ?? 0,
      status: row['status']?.toString() ?? 'open',
      lockAt:
          DateTime.tryParse(row['lock_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  PoolEntry _poolEntryFromRow(Map<String, dynamic> row) {
    return PoolEntry(
      id: row['id']?.toString() ?? '',
      poolId: row['challenge_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      userName: 'You',
      predictedHomeScore: (row['predicted_home_score'] as num?)?.toInt() ?? 0,
      predictedAwayScore: (row['predicted_away_score'] as num?)?.toInt() ?? 0,
      stake: (row['stake_fet'] as num?)?.toInt() ?? 0,
      status: switch (row['status']?.toString()) {
        'won' => 'winner',
        'lost' => 'loser',
        'refunded' => 'refunded',
        _ => 'active',
      },
      payout: (row['payout_fet'] as num?)?.toInt() ?? 0,
    );
  }
}
