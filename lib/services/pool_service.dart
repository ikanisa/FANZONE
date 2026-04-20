import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/gateway_providers.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/failures.dart';
import '../core/logging/app_logger.dart';
import '../features/predict/data/predict_gateway_models.dart';
import '../models/pool.dart';
import '../providers/auth_provider.dart';

part 'pool_service.g.dart';

@riverpod
class PoolService extends _$PoolService {
  @override
  FutureOr<List<ScorePool>> build() async {
    ref.watch(authStateProvider);
    return ref.read(predictionPoolGatewayProvider).getPools();
  }

  Future<void> createPool({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required int stake,
  }) async {
    if (state is AsyncLoading) return;

    if (ref.read(authServiceProvider).currentUser == null) {
      throw const AuthFailure();
    }

    if (stake < 10) {
      throw const ValidationFailure(
        message: 'Minimum stake is 10 FET',
        code: 'min_stake',
      );
    }

    if (homeScore < 0 || awayScore < 0) {
      throw const ValidationFailure(
        message: 'Scores must be zero or greater',
        code: 'invalid_score',
      );
    }

    final previous = state;
    state = const AsyncLoading();

    try {
      await ref
          .read(predictionPoolGatewayProvider)
          .createPool(
            PoolCreateRequestDto(
              matchId: matchId,
              homeScore: homeScore,
              awayScore: awayScore,
              stake: stake,
            ),
          );
      ref.invalidateSelf();
      ref.invalidate(myEntriesProvider);
    } catch (error, stack) {
      final failure = mapExceptionToFailure(error, stack);
      AppLogger.w('createPool failed: ${failure.message}');
      state = previous;
      throw failure;
    }
  }

  Future<void> joinPool({
    required String poolId,
    required int homeScore,
    required int awayScore,
    required int stake,
  }) async {
    if (state is AsyncLoading) return;

    if (ref.read(authServiceProvider).currentUser == null) {
      throw const AuthFailure();
    }

    if (homeScore < 0 || awayScore < 0) {
      throw const ValidationFailure(
        message: 'Scores must be zero or greater',
        code: 'invalid_score',
      );
    }

    final previous = state;
    state = const AsyncLoading();

    try {
      await ref
          .read(predictionPoolGatewayProvider)
          .joinPool(
            PoolJoinRequestDto(
              poolId: poolId,
              homeScore: homeScore,
              awayScore: awayScore,
            ),
          );
      ref.invalidateSelf();
      ref.invalidate(myEntriesProvider);
    } catch (error, stack) {
      final failure = mapExceptionToFailure(error, stack);
      AppLogger.w('joinPool failed: ${failure.message}');
      state = previous;
      throw failure;
    }
  }
}

@riverpod
class MyEntries extends _$MyEntries {
  @override
  FutureOr<List<PoolEntry>> build() async {
    ref.watch(authStateProvider);

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return const [];

    return ref.read(predictionPoolGatewayProvider).getMyEntries(userId);
  }
}

@riverpod
FutureOr<ScorePool?> poolDetail(Ref ref, String id) async {
  return ref.read(predictionPoolGatewayProvider).getPoolDetail(id);
}
