import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../core/logging/app_logger.dart';
import '../data/team_search_database.dart';
import '../features/onboarding/data/onboarding_gateway.dart';
import '../features/settings/data/preferences_gateway.dart';
import 'auth_provider.dart';
import 'favorite_teams_provider.dart';

/// Persistent favourites state — teams and competitions.
class FavouritesState {
  const FavouritesState({
    this.teamIds = const {},
    this.competitionIds = const {},
  });

  final Set<String> teamIds;
  final Set<String> competitionIds;

  FavouritesState copyWith({
    Set<String>? teamIds,
    Set<String>? competitionIds,
  }) => FavouritesState(
    teamIds: teamIds ?? this.teamIds,
    competitionIds: competitionIds ?? this.competitionIds,
  );

  bool isTeamFavourite(String id) => teamIds.contains(id);

  bool isCompetitionFavourite(String id) => competitionIds.contains(id);

  bool get isEmpty => teamIds.isEmpty && competitionIds.isEmpty;

  int get totalCount => teamIds.length + competitionIds.length;
}

class FavouritesNotifier extends AsyncNotifier<FavouritesState> {
  CompetitionPreferencesGateway get _gateway =>
      ref.read(competitionPreferencesGatewayProvider);
  OnboardingGateway get _onboardingGateway =>
      ref.read(onboardingGatewayProvider);

  @override
  Future<FavouritesState> build() async {
    ref.watch(authStateProvider);

    final userId = ref.read(authServiceProvider).currentUser?.id;
    final competitionScope = _competitionStorageScope(userId);
    final localCompetitionSelections = await _gateway
        .readCachedCompetitionFavourites(scope: competitionScope);
    final favoriteTeams = await ref.watch(favoriteTeamRecordsProvider.future);

    var nextState = FavouritesState(
      teamIds: favoriteTeams.map((team) => team.teamId).toSet(),
      competitionIds: localCompetitionSelections.competitionIds,
    );

    if (userId != null) {
      final guestCompetitionSelections = await _gateway
          .readCachedCompetitionFavourites(
            scope: _competitionStorageScope(null),
          );
      nextState = nextState.copyWith(
        competitionIds: {
          ...nextState.competitionIds,
          ...guestCompetitionSelections.competitionIds,
        },
      );

      try {
        final remoteCompetitionSelections = await _gateway
            .readRemoteCompetitionFavourites(userId);
        nextState = nextState.copyWith(
          competitionIds: {
            ...nextState.competitionIds,
            ...remoteCompetitionSelections.competitionIds,
          },
        );
      } catch (error) {
        AppLogger.d('Failed to sync remote competition favourites: $error');
      }
    }

    await _persistCompetitionState(nextState, scope: competitionScope);
    return nextState;
  }

  String _competitionStorageScope(String? userId) =>
      userId == null ? 'guest' : 'user_$userId';

  Future<void> _persistCompetitionState(
    FavouritesState favourites, {
    required String scope,
  }) async {
    await _gateway.writeCachedCompetitionFavourites(
      scope: scope,
      selections: CompetitionSelectionsDto(
        competitionIds: favourites.competitionIds,
      ),
    );
  }

  Future<void> toggleTeam(String teamId) async {
    final current = state.valueOrNull ?? const FavouritesState();
    final teamIds = Set<String>.from(current.teamIds);
    final isFollowing = teamIds.contains(teamId);

    if (isFollowing) {
      teamIds.remove(teamId);
    } else {
      teamIds.add(teamId);
    }

    final next = current.copyWith(teamIds: teamIds);
    state = AsyncValue.data(next);

    try {
      if (isFollowing) {
        await _onboardingGateway.deleteFavoriteTeam(teamId);
      } else {
        final team = allTeams
            .where((candidate) => candidate.id == teamId)
            .firstOrNull;
        if (team == null) {
          throw StateError('Unknown team id: $teamId');
        }
        await _onboardingGateway.addFavoriteTeam(team);
      }
      ref.invalidate(favoriteTeamRecordsProvider);
    } catch (error) {
      AppLogger.d('Failed to toggle favorite team: $error');
      state = AsyncValue.data(current);
    }
  }

  Future<void> toggleCompetition(String competitionId) async {
    final current = state.valueOrNull ?? const FavouritesState();
    final competitionIds = Set<String>.from(current.competitionIds);
    final userId = ref.read(authServiceProvider).currentUser?.id;
    final scope = _competitionStorageScope(userId);
    final isFollowing = competitionIds.contains(competitionId);

    if (isFollowing) {
      competitionIds.remove(competitionId);
    } else {
      competitionIds.add(competitionId);
    }

    final next = current.copyWith(competitionIds: competitionIds);
    state = AsyncValue.data(next);
    await _persistCompetitionState(next, scope: scope);

    if (userId == null) return;

    try {
      await _gateway.setRemoteCompetitionFavourite(
        userId: userId,
        competitionId: competitionId,
        enabled: !isFollowing,
      );
    } catch (error) {
      AppLogger.d('Failed to toggle competition follow: $error');
      state = AsyncValue.data(current);
      await _persistCompetitionState(current, scope: scope);
    }
  }

  Future<void> clearAll() async {
    final scope = _competitionStorageScope(
      ref.read(authServiceProvider).currentUser?.id,
    );
    const empty = FavouritesState();
    state = const AsyncValue.data(empty);
    await _persistCompetitionState(empty, scope: scope);
  }
}

final favouritesProvider =
    AsyncNotifierProvider<FavouritesNotifier, FavouritesState>(
      FavouritesNotifier.new,
    );
