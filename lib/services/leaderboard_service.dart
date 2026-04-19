import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/injection.dart';
import '../features/predict/data/leaderboard_gateway.dart';
import '../providers/auth_provider.dart';

part 'leaderboard_service.g.dart';

@riverpod
class GlobalLeaderboard extends _$GlobalLeaderboard {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    final rows = await getIt<LeaderboardGateway>().getGlobalLeaderboard();
    return rows;
  }
}

@riverpod
FutureOr<int?> userRank(Ref ref) async {
  ref.watch(authStateProvider);
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return null;
  return getIt<LeaderboardGateway>().getUserRank(userId);
}
