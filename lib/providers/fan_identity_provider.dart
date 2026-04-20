import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../models/fan_identity_model.dart';
import 'auth_provider.dart';

final fanLevelsProvider = FutureProvider<List<FanLevel>>((ref) async {
  return ref.read(fanProfileGatewayProvider).getFanLevels();
});

final fanBadgesProvider = FutureProvider<List<FanBadge>>((ref) async {
  return ref.read(fanProfileGatewayProvider).getFanBadges();
});

final fanProfileProvider = FutureProvider.autoDispose<FanProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final profile = await ref
      .read(fanProfileGatewayProvider)
      .getFanProfile(user.id);
  if (profile == null) return null;

  final levels = ref.read(fanLevelsProvider).valueOrNull ?? [];
  final level = levels.cast<FanLevel?>().firstWhere(
    (candidate) => candidate!.level == profile.currentLevel,
    orElse: () => null,
  );

  return level != null ? profile.withLevel(level) : profile;
});

final earnedBadgesProvider = FutureProvider.autoDispose<List<EarnedBadge>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(fanProfileGatewayProvider).getEarnedBadges(user.id);
});

final xpHistoryProvider = FutureProvider.autoDispose<List<XpLogEntry>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(fanProfileGatewayProvider).getXpHistory(user.id);
});
