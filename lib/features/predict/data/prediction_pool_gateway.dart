import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/pool.dart';
import 'predict_gateway_models.dart';
import 'predict_gateway_shared.dart';

abstract interface class PredictionPoolGateway {
  Future<List<ScorePool>> getPools();

  Future<void> createPool(PoolCreateRequestDto request);

  Future<void> joinPool(PoolJoinRequestDto request);

  Future<List<PoolEntry>> getMyEntries(String userId);

  Future<ScorePool?> getPoolDetail(String id);
}

class SupabasePredictionPoolGateway implements PredictionPoolGateway {
  SupabasePredictionPoolGateway(this._connection);

  final SupabaseConnection _connection;
  final List<ScorePool> _localPools = <ScorePool>[
    ScorePool(
      id: 'pool_1',
      matchId: 'match_live_1',
      matchName: 'Liverpool vs Arsenal',
      creatorId: 'user_1',
      creatorName: 'FAN Malta',
      creatorPrediction: '2-1',
      stake: 25,
      totalPool: 250,
      participantsCount: 10,
      status: 'open',
      lockAt: DateTime.now().add(const Duration(hours: 4)),
    ),
  ];
  final Map<String, List<PoolEntry>> _localEntriesByUser =
      <String, List<PoolEntry>>{};

  @override
  Future<List<ScorePool>> getPools() async {
    final client = _connection.client;
    if (client == null) {
      final seeded = _seededPools();
      if (seeded.isNotEmpty) return seeded;
      throwPredictUnavailable('Pools');
    }

    try {
      final rows = await client
          .from('prediction_challenges')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      final pools = (rows as List)
          .whereType<Map>()
          .map((row) => _poolFromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return pools;
    } catch (error) {
      AppLogger.d('Failed to load pools: $error');
      final seeded = _seededPools();
      if (seeded.isNotEmpty) return seeded;
      throwPredictUnavailable('Pools');
    }
  }

  @override
  Future<void> createPool(PoolCreateRequestDto request) async {
    final client = _connection.client;
    if (client == null) {
      throwPredictUnavailable('Pool creation');
    }

    try {
      await client.rpc(
        'create_pool_rate_limited',
        params: {
          'p_match_id': request.matchId,
          'p_home_score': request.homeScore,
          'p_away_score': request.awayScore,
          'p_stake': request.stake,
        },
      );
    } catch (error) {
      AppLogger.d('Failed to create pool remotely: $error');
      rethrow;
    }
  }

  @override
  Future<void> joinPool(PoolJoinRequestDto request) async {
    final client = _connection.client;
    if (client == null) {
      throwPredictUnavailable('Joining a pool');
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
      AppLogger.d('Failed to join pool remotely: $error');
      rethrow;
    }
  }

  @override
  Future<List<PoolEntry>> getMyEntries(String userId) async {
    final client = _connection.client;
    if (client == null) {
      final cached = _cachedEntries(userId);
      if (cached.isNotEmpty) return cached;
      throwPredictUnavailable('Pool history');
    }

    try {
      final rows = await client
          .from('prediction_challenge_entries')
          .select()
          .eq('user_id', userId)
          .order('joined_at', ascending: false);
      final entries = (rows as List)
          .whereType<Map>()
          .map((row) => _poolEntryFromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return entries;
    } catch (error) {
      AppLogger.d('Failed to load pool entries: $error');
      final cached = _cachedEntries(userId);
      if (cached.isNotEmpty) return cached;
      throwPredictUnavailable('Pool history');
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

  List<ScorePool> _seededPools() {
    if (!allowPredictSeedFallback) return const <ScorePool>[];
    return [..._localPools];
  }

  List<PoolEntry> _cachedEntries(String userId) {
    if (!allowPredictSeedFallback) return const <PoolEntry>[];
    return [...(_localEntriesByUser[userId] ?? const <PoolEntry>[])];
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
