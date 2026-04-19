import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/injection.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/failures.dart';
import '../core/logging/app_logger.dart';
import '../features/community/data/team_news_gateway.dart';
import '../features/community/data/team_support_gateway.dart';
import '../models/team_contribution_model.dart';
import '../models/team_news_model.dart';
import '../models/team_supporter_model.dart';
import '../providers/auth_provider.dart';

part 'team_community_service.g.dart';

@riverpod
class SupportedTeamsService extends _$SupportedTeamsService {
  @override
  FutureOr<Set<String>> build() async {
    ref.watch(authStateProvider);

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return const <String>{};

    return getIt<TeamSupportGateway>().getSupportedTeamIds(userId);
  }

  Future<String?> supportTeam(String teamId) async {
    if (ref.read(authServiceProvider).currentUser == null) {
      throw StateError('Not authenticated');
    }

    try {
      final fanId = await getIt<TeamSupportGateway>().supportTeam(teamId);
      final current = state.valueOrNull ?? <String>{};
      state = AsyncValue.data({...current, teamId});
      return fanId;
    } catch (error, stack) {
      final failure = mapExceptionToFailure(error, stack);
      AppLogger.w('Support team failed: ${failure.message}');
      throw failure;
    }
  }

  Future<void> unsupportTeam(String teamId) async {
    if (ref.read(authServiceProvider).currentUser == null) {
      throw const AuthFailure();
    }

    try {
      await getIt<TeamSupportGateway>().unsupportTeam(teamId);
      final current = state.valueOrNull ?? <String>{};
      state = AsyncValue.data({...current}..remove(teamId));
    } catch (error, stack) {
      final failure = mapExceptionToFailure(error, stack);
      AppLogger.w('Unsupport team failed: ${failure.message}');
      throw failure;
    }
  }

  Future<void> toggleSupport(String teamId) async {
    final supported = state.valueOrNull ?? <String>{};
    if (supported.contains(teamId)) {
      await unsupportTeam(teamId);
    } else {
      await supportTeam(teamId);
    }
  }

  bool isSupporting(String teamId) =>
      state.valueOrNull?.contains(teamId) ?? false;
}

@riverpod
FutureOr<TeamCommunityStats?> teamCommunityStats(Ref ref, String teamId) async {
  return getIt<TeamSupportGateway>().getTeamCommunityStats(teamId);
}

@riverpod
FutureOr<List<AnonymousFanRecord>> teamAnonymousFans(
  Ref ref,
  String teamId, {
  int limit = 50,
}) async {
  return getIt<TeamSupportGateway>().getTeamAnonymousFans(teamId, limit: limit);
}

@riverpod
class TeamContributionService extends _$TeamContributionService {
  @override
  FutureOr<void> build() {}

  Future<int> contributeFet(String teamId, int amount) async {
    if (ref.read(authServiceProvider).currentUser == null) {
      throw StateError('Not authenticated');
    }

    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }

    state = const AsyncValue.loading();

    try {
      final balanceAfter = await getIt<TeamSupportGateway>().contributeFet(
        teamId,
        amount,
      );
      state = const AsyncValue.data(null);
      return balanceAfter;
    } catch (error, stack) {
      final failure = mapExceptionToFailure(error, stack);
      AppLogger.w('FET contribution failed: ${failure.message}');
      state = AsyncValue.error(failure, stack);
      throw failure;
    }
  }
}

@riverpod
FutureOr<List<TeamContributionModel>> teamContributionHistory(
  Ref ref,
  String teamId,
) async {
  ref.watch(authStateProvider);
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return const [];

  return getIt<TeamSupportGateway>().getTeamContributionHistory(userId, teamId);
}

@riverpod
FutureOr<List<TeamNewsModel>> teamNews(
  Ref ref,
  String teamId, {
  String? category,
  int limit = 20,
}) async {
  return getIt<TeamNewsGateway>().getTeamNews(
    teamId,
    category: category,
    limit: limit,
  );
}

@riverpod
FutureOr<TeamNewsModel?> teamNewsDetail(Ref ref, String newsId) async {
  return getIt<TeamNewsGateway>().getTeamNewsDetail(newsId);
}

@riverpod
FutureOr<List<Map<String, dynamic>>> featuredTeamsRaw(Ref ref) async {
  return getIt<TeamSupportGateway>().getFeaturedTeamsRaw();
}
