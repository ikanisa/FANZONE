import 'package:injectable/injectable.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/daily_challenge_model.dart';
import '../../../models/pool.dart';
import '../../../models/prediction_slip_model.dart';
import '../../../providers/prediction_slip_provider.dart';

abstract interface class PredictGateway {
  Future<List<ScorePool>> getPools();

  Future<void> createPool(PoolCreateRequestDto request);

  Future<void> joinPool(PoolJoinRequestDto request);

  Future<List<PoolEntry>> getMyEntries(String userId);

  Future<ScorePool?> getPoolDetail(String id);

  Future<List<Map<String, dynamic>>> getGlobalLeaderboard();

  Future<int?> getUserRank(String userId);

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

  Future<String> submitPredictionSlip(PredictionSlipSubmissionDto request);

  Future<List<PredictionSlipModel>> getMyPredictionSlips(
    String userId, {
    int limit,
  });
}

class PoolCreateRequestDto {
  const PoolCreateRequestDto({
    required this.matchId,
    required this.homeScore,
    required this.awayScore,
    required this.stake,
  });

  final String matchId;
  final int homeScore;
  final int awayScore;
  final int stake;
}

class PoolJoinRequestDto {
  const PoolJoinRequestDto({
    required this.poolId,
    required this.homeScore,
    required this.awayScore,
  });

  final String poolId;
  final int homeScore;
  final int awayScore;
}

class PredictionSlipSubmissionDto {
  const PredictionSlipSubmissionDto({
    required this.selections,
    required this.stake,
  });

  final List<PredictionSelection> selections;
  final int stake;
}

class GlobalLeaderboardEntryDto {
  const GlobalLeaderboardEntryDto({
    required this.rank,
    required this.name,
    required this.fet,
    this.level,
  });

  factory GlobalLeaderboardEntryDto.fromJson(Map<String, dynamic> json) {
    return GlobalLeaderboardEntryDto(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Fan',
      fet: (json['fet'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt(),
    );
  }

  final int rank;
  final String name;
  final int fet;
  final int? level;

  Map<String, dynamic> toJson() {
    return {'rank': rank, 'name': name, 'fet': fet, 'level': level};
  }
}

@LazySingleton(as: PredictGateway)
class SupabasePredictGateway implements PredictGateway {
  SupabasePredictGateway(this._connection);

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
  final Map<String, List<DailyChallengeEntry>> _localDailyEntries =
      <String, List<DailyChallengeEntry>>{};
  final Map<String, List<PredictionSlipModel>> _localSlipsByUser =
      <String, List<PredictionSlipModel>>{};

  @override
  Future<List<ScorePool>> getPools() async {
    final client = _connection.client;
    if (client == null) return [..._localPools];

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
      return pools.isEmpty ? [..._localPools] : pools;
    } catch (error) {
      AppLogger.d('Failed to load pools: $error');
      return [..._localPools];
    }
  }

  @override
  Future<void> createPool(PoolCreateRequestDto request) async {
    final client = _connection.client;
    if (client != null) {
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
        return;
      } catch (error) {
        AppLogger.d('Failed to create pool remotely: $error');
      }
    }

    _localPools.insert(
      0,
      ScorePool(
        id: 'pool_${DateTime.now().millisecondsSinceEpoch}',
        matchId: request.matchId,
        matchName: 'Custom match pool',
        creatorId: _currentUserId(),
        creatorName: 'You',
        creatorPrediction: '${request.homeScore}-${request.awayScore}',
        stake: request.stake,
        totalPool: request.stake,
        participantsCount: 1,
        status: 'open',
        lockAt: DateTime.now().add(const Duration(hours: 3)),
      ),
    );
  }

  @override
  Future<void> joinPool(PoolJoinRequestDto request) async {
    final client = _connection.client;
    if (client != null) {
      try {
        await client.rpc(
          'join_pool',
          params: {
            'p_pool_id': request.poolId,
            'p_home_score': request.homeScore,
            'p_away_score': request.awayScore,
          },
        );
        return;
      } catch (error) {
        AppLogger.d('Failed to join pool remotely: $error');
      }
    }

    for (var index = 0; index < _localPools.length; index += 1) {
      final pool = _localPools[index];
      if (pool.id != request.poolId) continue;

      _localPools[index] = pool.copyWith(
        participantsCount: pool.participantsCount + 1,
        totalPool: pool.totalPool + pool.stake,
      );

      final userId = _currentUserId();
      final entries = _localEntriesByUser[userId] ?? <PoolEntry>[];
      _localEntriesByUser[userId] = [
        PoolEntry(
          id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
          poolId: request.poolId,
          userId: userId,
          userName: 'You',
          predictedHomeScore: request.homeScore,
          predictedAwayScore: request.awayScore,
          stake: pool.stake,
          status: 'active',
          payout: 0,
        ),
        ...entries,
      ];
      break;
    }
  }

  @override
  Future<List<PoolEntry>> getMyEntries(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return [...(_localEntriesByUser[userId] ?? const <PoolEntry>[])];
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
      return entries.isEmpty
          ? [...(_localEntriesByUser[userId] ?? const <PoolEntry>[])]
          : entries;
    } catch (error) {
      AppLogger.d('Failed to load pool entries: $error');
      return [...(_localEntriesByUser[userId] ?? const <PoolEntry>[])];
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

  @override
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard() async {
    final client = _connection.client;
    if (client == null) {
      return _fallbackLeaderboard
          .map((row) => row.toJson())
          .toList(growable: false);
    }

    try {
      final rows = await client
          .from('public_leaderboard')
          .select('display_name, total_fet')
          .order('total_fet', ascending: false)
          .limit(50);

      final leaderboard = <GlobalLeaderboardEntryDto>[];
      for (var index = 0; index < (rows as List).length; index += 1) {
        final row = Map<String, dynamic>.from(rows[index] as Map);
        leaderboard.add(
          GlobalLeaderboardEntryDto(
            rank: index + 1,
            name: row['display_name']?.toString() ?? 'Fan',
            fet: (row['total_fet'] as num?)?.toInt() ?? 0,
            level: 1,
          ),
        );
      }

      return (leaderboard.isEmpty ? _fallbackLeaderboard : leaderboard)
          .map((row) => row.toJson())
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load global leaderboard: $error');
      return _fallbackLeaderboard
          .map((row) => row.toJson())
          .toList(growable: false);
    }
  }

  @override
  Future<int?> getUserRank(String userId) async {
    final leaderboard = await getGlobalLeaderboard();
    for (final row in leaderboard) {
      if (row['user_id']?.toString() == userId) {
        return (row['rank'] as num?)?.toInt();
      }
    }

    final client = _connection.client;
    if (client == null) return 4;

    try {
      final rows = await client
          .from('public_leaderboard')
          .select('user_id')
          .order('total_fet', ascending: false);
      for (var index = 0; index < (rows as List).length; index += 1) {
        final row = rows[index] as Map;
        if (row['user_id']?.toString() == userId) {
          return index + 1;
        }
      }
      return null;
    } catch (error) {
      AppLogger.d('Failed to resolve user rank: $error');
      return 4;
    }
  }

  @override
  Future<DailyChallenge?> getTodaysDailyChallenge() async {
    final client = _connection.client;
    if (client == null) return _fallbackDailyChallenge();

    try {
      final row = await client
          .from('daily_challenges')
          .select()
          .eq('status', 'active')
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null
          ? _fallbackDailyChallenge()
          : DailyChallenge.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load daily challenge: $error');
      return _fallbackDailyChallenge();
    }
  }

  @override
  Future<void> submitDailyPrediction({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    final client = _connection.client;
    if (client != null) {
      try {
        await client.rpc(
          'submit_daily_prediction',
          params: {
            'p_challenge_id': challengeId,
            'p_home_score': homeScore,
            'p_away_score': awayScore,
          },
        );
        return;
      } catch (error) {
        AppLogger.d('Failed to submit daily prediction remotely: $error');
      }
    }

    final userId = _currentUserId();
    final entry = DailyChallengeEntry(
      id: 'daily_entry_${DateTime.now().millisecondsSinceEpoch}',
      challengeId: challengeId,
      userId: userId,
      predictedHomeScore: homeScore,
      predictedAwayScore: awayScore,
      result: 'pending',
      submittedAt: DateTime.now(),
    );
    final entries = _localDailyEntries[userId] ?? <DailyChallengeEntry>[];
    _localDailyEntries[userId] = [entry, ...entries];
  }

  @override
  Future<DailyChallengeEntry?> getMyDailyEntry({
    required String challengeId,
    required String userId,
  }) async {
    final client = _connection.client;
    if (client != null) {
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
      } catch (error) {
        AppLogger.d('Failed to load daily entry: $error');
      }
    }

    final entries = _localDailyEntries[userId] ?? const <DailyChallengeEntry>[];
    for (final entry in entries) {
      if (entry.challengeId == challengeId) return entry;
    }
    return null;
  }

  @override
  Future<List<DailyChallengeEntry>> getDailyChallengeHistory(String userId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('daily_challenge_entries')
            .select()
            .eq('user_id', userId)
            .order('submitted_at', ascending: false);
        final entries = (rows as List)
            .whereType<Map>()
            .map(
              (row) => DailyChallengeEntry.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(growable: false);
        if (entries.isNotEmpty) return entries;
      } catch (error) {
        AppLogger.d('Failed to load daily challenge history: $error');
      }
    }

    return [...(_localDailyEntries[userId] ?? const <DailyChallengeEntry>[])];
  }

  @override
  Future<String> submitPredictionSlip(
    PredictionSlipSubmissionDto request,
  ) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final response = await client.rpc(
          'submit_prediction_slip',
          params: {
            'p_selections': request.selections
                .map(
                  (selection) => {
                    'match_id': selection.match.id,
                    'match_name':
                        '${selection.match.homeTeam} vs ${selection.match.awayTeam}',
                    'market': selection.market,
                    'selection': selection.selection,
                    'potential_earn_fet':
                        selection.projectedEarnForStake(request.stake),
                  },
                )
                .toList(growable: false),
          },
        );

        if (response is String) return response;
        if (response is Map && response['slip_id'] != null) {
          return response['slip_id'].toString();
        }
      } catch (error) {
        AppLogger.d('Failed to submit prediction slip remotely: $error');
      }
    }

    final userId = _currentUserId();
    final slip = PredictionSlipModel(
      id: 'slip_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      status: 'submitted',
      selectionCount: request.selections.length,
      projectedEarnFet: request.selections.fold<int>(
        request.stake,
        (sum, selection) =>
            sum + selection.projectedEarnForStake(request.stake),
      ),
      submittedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final slips = _localSlipsByUser[userId] ?? <PredictionSlipModel>[];
    _localSlipsByUser[userId] = [slip, ...slips];
    return slip.id;
  }

  @override
  Future<List<PredictionSlipModel>> getMyPredictionSlips(
    String userId, {
    int limit = 20,
  }) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('prediction_slips')
            .select()
            .eq('user_id', userId)
            .order('submitted_at', ascending: false)
            .limit(limit);
        final slips = (rows as List)
            .whereType<Map>()
            .map(
              (row) => PredictionSlipModel.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(growable: false);
        if (slips.isNotEmpty) return slips;
      } catch (error) {
        AppLogger.d('Failed to load prediction slips: $error');
      }
    }

    final slips = _localSlipsByUser[userId] ?? const <PredictionSlipModel>[];
    return slips.take(limit).toList(growable: false);
  }

  String _currentUserId() {
    final userId = _connection.currentUser?.id;
    if (userId == null) return 'local-user';
    return userId;
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
      creatorPrediction: row['official_home_score'] != null &&
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

DailyChallenge _fallbackDailyChallenge() {
  final today = DateTime.now();
  return DailyChallenge(
    id: 'daily_1',
    date: DateTime(today.year, today.month, today.day),
    matchId: 'match_live_1',
    matchName: 'Liverpool vs Arsenal',
    title: 'Predict the final score',
    description: 'Submit one scoreline before kickoff for a free FET reward.',
    rewardFet: 25,
    bonusExactFet: 50,
    status: 'active',
    totalEntries: 132,
    totalWinners: 7,
  );
}

const List<GlobalLeaderboardEntryDto> _fallbackLeaderboard =
    <GlobalLeaderboardEntryDto>[
      GlobalLeaderboardEntryDto(rank: 1, name: 'FAN Malta', fet: 920, level: 3),
      GlobalLeaderboardEntryDto(rank: 2, name: 'FAN Kigali', fet: 880, level: 2),
      GlobalLeaderboardEntryDto(rank: 3, name: 'FAN Madrid', fet: 860, level: 2),
      GlobalLeaderboardEntryDto(rank: 4, name: 'FAN Lagos', fet: 810, level: 2),
    ];
