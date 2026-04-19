import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/di/injection.dart';
import '../../../data/team_search_database.dart';
import '../../../providers/favorite_teams_provider.dart';
import '../../../providers/auth_provider.dart';

const _profileIdentityCacheKey = 'profile_identity_team_id_v1';

final profileIdentityProvider =
    AsyncNotifierProvider.autoDispose<
      ProfileIdentityController,
      FavoriteTeamRecordDto?
    >(ProfileIdentityController.new);

class ProfileIdentityController
    extends AutoDisposeAsyncNotifier<FavoriteTeamRecordDto?> {
  CacheService get _cache => getIt<CacheService>();

  @override
  Future<FavoriteTeamRecordDto?> build() => _loadSelection();

  Future<void> setSelectedTeam(FavoriteTeamRecordDto? team) async {
    if (team == null) {
      await _cache.remove(_profileIdentityCacheKey);
      state = const AsyncValue.data(null);
      return;
    }

    await _cache.setString(_profileIdentityCacheKey, team.teamId);
    state = AsyncValue.data(team);
  }

  Future<void> refresh() async {
    ref.invalidate(favoriteTeamRecordsProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadSelection);
  }

  Future<FavoriteTeamRecordDto?> _loadSelection() async {
    ref.watch(authStateProvider);

    final teams = await ref.watch(favoriteTeamRecordsProvider.future);
    if (teams.isEmpty) {
      await _cache.remove(_profileIdentityCacheKey);
      return null;
    }

    final cachedTeamId = await _cache.getString(_profileIdentityCacheKey);
    final selected = _resolveSelection(teams, cachedTeamId);

    if (selected == null) {
      await _cache.remove(_profileIdentityCacheKey);
      return null;
    }

    if (cachedTeamId != selected.teamId) {
      await _cache.setString(_profileIdentityCacheKey, selected.teamId);
    }

    return selected;
  }

  FavoriteTeamRecordDto? _resolveSelection(
    List<FavoriteTeamRecordDto> teams,
    String? cachedTeamId,
  ) {
    if (cachedTeamId != null && cachedTeamId.isNotEmpty) {
      for (final team in teams) {
        if (team.teamId == cachedTeamId) return team;
      }
    }

    for (final team in teams) {
      if (team.source == 'local') return team;
    }

    return teams.first;
  }
}
