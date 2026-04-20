import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/gateway_providers.dart';
import '../models/daily_challenge_model.dart';
import '../providers/auth_provider.dart';

part 'daily_challenge_service.g.dart';

@riverpod
class DailyChallengeService extends _$DailyChallengeService {
  @override
  FutureOr<DailyChallenge?> build() async {
    ref.watch(authStateProvider);
    return ref.read(dailyChallengeGatewayProvider).getTodaysDailyChallenge();
  }

  Future<void> submitPrediction({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    await ref
        .read(dailyChallengeGatewayProvider)
        .submitDailyPrediction(
          challengeId: challengeId,
          homeScore: homeScore,
          awayScore: awayScore,
        );

    ref.invalidateSelf();
    ref.invalidate(myDailyEntryProvider);
    ref.invalidate(dailyChallengeHistoryProvider);
  }
}

@riverpod
FutureOr<DailyChallengeEntry?> myDailyEntry(Ref ref) async {
  ref.watch(authStateProvider);

  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return null;

  final challenge = await ref.watch(dailyChallengeServiceProvider.future);
  if (challenge == null) return null;

  return ref
      .read(dailyChallengeGatewayProvider)
      .getMyDailyEntry(challengeId: challenge.id, userId: userId);
}

@riverpod
FutureOr<List<DailyChallengeEntry>> dailyChallengeHistory(Ref ref) async {
  ref.watch(authStateProvider);

  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return const [];

  return ref
      .read(dailyChallengeGatewayProvider)
      .getDailyChallengeHistory(userId);
}
