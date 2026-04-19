import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../core/logging/app_logger.dart';
import '../features/settings/data/preferences_gateway.dart';
import 'auth_provider.dart';

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
  PreferencesGateway get _gateway => getIt<PreferencesGateway>();

  @override
  Future<FavouritesState> build() async {
    ref.watch(authStateProvider);

    final userId = ref.read(authServiceProvider).currentUser?.id;
    final scope = _storageScope(userId);
    final local = await _gateway.readCachedFavourites(scope: scope);

    var nextState = FavouritesState(
      teamIds: local.teamIds,
      competitionIds: local.competitionIds,
    );

    if (userId != null) {
      final guest = await _gateway.readCachedFavourites(
        scope: _storageScope(null),
      );
      nextState = nextState.copyWith(
        teamIds: {...nextState.teamIds, ...guest.teamIds},
        competitionIds: {
          ...nextState.competitionIds,
          ...guest.competitionIds,
        },
      );

      try {
        final remote = await _gateway.readRemoteFavourites(userId);
        nextState = nextState.copyWith(
          teamIds: {...nextState.teamIds, ...remote.teamIds},
          competitionIds: {
            ...nextState.competitionIds,
            ...remote.competitionIds,
          },
        );
      } catch (error) {
        AppLogger.d('Failed to sync remote favourites: $error');
      }
    }

    await _persistState(nextState, scope: scope);
    return nextState;
  }

  String _storageScope(String? userId) =>
      userId == null ? 'guest' : 'user_$userId';

  Future<void> _persistState(
    FavouritesState favourites, {
    required String scope,
  }) async {
    await _gateway.writeCachedFavourites(
      scope: scope,
      selections: FavouriteSelectionsDto(
        teamIds: favourites.teamIds,
        competitionIds: favourites.competitionIds,
      ),
    );
  }

  Future<void> toggleTeam(String teamId) async {
    final current = state.valueOrNull ?? const FavouritesState();
    final teamIds = Set<String>.from(current.teamIds);
    final userId = ref.read(authServiceProvider).currentUser?.id;
    final scope = _storageScope(userId);
    final isFollowing = teamIds.contains(teamId);

    if (isFollowing) {
      teamIds.remove(teamId);
    } else {
      teamIds.add(teamId);
    }

    final next = current.copyWith(teamIds: teamIds);
    state = AsyncValue.data(next);
    await _persistState(next, scope: scope);

    if (userId == null) return;

    try {
      await _gateway.setRemoteTeamFavourite(
        userId: userId,
        teamId: teamId,
        enabled: !isFollowing,
      );
    } catch (error) {
      AppLogger.d('Failed to toggle team follow: $error');
      state = AsyncValue.data(current);
      await _persistState(current, scope: scope);
    }
  }

  Future<void> toggleCompetition(String competitionId) async {
    final current = state.valueOrNull ?? const FavouritesState();
    final competitionIds = Set<String>.from(current.competitionIds);
    final userId = ref.read(authServiceProvider).currentUser?.id;
    final scope = _storageScope(userId);
    final isFollowing = competitionIds.contains(competitionId);

    if (isFollowing) {
      competitionIds.remove(competitionId);
    } else {
      competitionIds.add(competitionId);
    }

    final next = current.copyWith(competitionIds: competitionIds);
    state = AsyncValue.data(next);
    await _persistState(next, scope: scope);

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
      await _persistState(current, scope: scope);
    }
  }

  Future<void> clearAll() async {
    final scope = _storageScope(ref.read(authServiceProvider).currentUser?.id);
    const empty = FavouritesState();
    state = const AsyncValue.data(empty);
    await _persistState(empty, scope: scope);
  }
}

final favouritesProvider =
    AsyncNotifierProvider<FavouritesNotifier, FavouritesState>(
      FavouritesNotifier.new,
    );
