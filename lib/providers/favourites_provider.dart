import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import '../core/logging/app_logger.dart';
import '../core/network/supabase_provider.dart';

const _kTeamIds = 'fz_favourite_team_ids';
const _kCompIds = 'fz_favourite_competition_ids';

/// Persistent favourites state — teams and competitions.
class FavouritesState {
  final Set<String> teamIds;
  final Set<String> competitionIds;

  const FavouritesState({
    this.teamIds = const {},
    this.competitionIds = const {},
  });

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

/// Favourites notifier — loads from SharedPreferences + Supabase async
/// and isolates persisted state per authenticated user.
class FavouritesNotifier extends AsyncNotifier<FavouritesState> {
  @override
  Future<FavouritesState> build() async {
    ref.watch(authStateProvider);

    final prefs = await SharedPreferences.getInstance();
    final userId = ref.read(authServiceProvider).currentUser?.id;
    final scope = _storageScope(userId);
    final localTeams = prefs.getStringList(_teamsKey(scope)) ?? [];
    final localCompetitions =
        prefs.getStringList(_competitionsKey(scope)) ?? [];

    var nextState = FavouritesState(
      teamIds: localTeams.toSet(),
      competitionIds: localCompetitions.toSet(),
    );

    // Preserve guest selections when the user signs in on the same device.
    if (userId != null) {
      final guestTeams =
          prefs.getStringList(_teamsKey(_storageScope(null))) ?? const [];
      final guestCompetitions =
          prefs.getStringList(_competitionsKey(_storageScope(null))) ??
          const [];
      nextState = nextState.copyWith(
        teamIds: {...nextState.teamIds, ...guestTeams},
        competitionIds: {...nextState.competitionIds, ...guestCompetitions},
      );
    }

    // Sync with remote favourites via Supabase client
    try {
      final client = ref.read(supabaseClientProvider);
      if (client != null && isAuthenticated(client)) {
        final responses = await Future.wait([
          client
              .from('user_followed_teams')
              .select('team_id')
              .eq('user_id', userId!),
          client
              .from('user_followed_competitions')
              .select('competition_id')
              .eq('user_id', userId),
        ]).timeout(supabaseTimeout);

        final remoteTeamIds = (responses[0] as List)
            .map((row) => row['team_id'] as String?)
            .whereType<String>()
            .toSet();
        final remoteCompIds = (responses[1] as List)
            .map((row) => row['competition_id'] as String?)
            .whereType<String>()
            .toSet();

        nextState = nextState.copyWith(
          teamIds: {...nextState.teamIds, ...remoteTeamIds},
          competitionIds: {...nextState.competitionIds, ...remoteCompIds},
        );
      }
    } catch (e) {
      AppLogger.d('Failed to sync remote favourites: $e');
    }

    await _persistState(nextState, scope: scope);
    return nextState;
  }

  String _storageScope(String? userId) =>
      userId == null ? 'guest' : 'user_$userId';

  String _teamsKey(String scope) => '${_kTeamIds}_$scope';

  String _competitionsKey(String scope) => '${_kCompIds}_$scope';

  Future<void> _persistState(
    FavouritesState favState, {
    required String scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_teamsKey(scope), favState.teamIds.toList());
    await prefs.setStringList(
      _competitionsKey(scope),
      favState.competitionIds.toList(),
    );
  }

  Future<void> toggleTeam(String teamId) async {
    final current = state.valueOrNull ?? const FavouritesState();
    final teamIds = Set<String>.from(current.teamIds);
    final client = ref.read(supabaseClientProvider);
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

    if (client == null || !isAuthenticated(client)) return;

    try {
      if (isFollowing) {
        await client
            .from('user_followed_teams')
            .delete()
            .eq('user_id', userId!)
            .eq('team_id', teamId)
            .timeout(supabaseTimeout);
      } else {
        await client
            .from('user_followed_teams')
            .upsert({'user_id': userId, 'team_id': teamId})
            .timeout(supabaseTimeout);
      }
    } catch (e) {
      AppLogger.d('Failed to toggle team follow: $e');
      // Rollback
      state = AsyncValue.data(current);
      await _persistState(current, scope: scope);
    }
  }

  Future<void> toggleCompetition(String competitionId) async {
    final current = state.valueOrNull ?? const FavouritesState();
    final competitionIds = Set<String>.from(current.competitionIds);
    final client = ref.read(supabaseClientProvider);
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

    if (client == null || !isAuthenticated(client)) return;

    try {
      if (isFollowing) {
        await client
            .from('user_followed_competitions')
            .delete()
            .eq('user_id', userId!)
            .eq('competition_id', competitionId)
            .timeout(supabaseTimeout);
      } else {
        await client
            .from('user_followed_competitions')
            .upsert({'user_id': userId, 'competition_id': competitionId})
            .timeout(supabaseTimeout);
      }
    } catch (e) {
      AppLogger.d('Failed to toggle competition follow: $e');
      // Rollback
      state = AsyncValue.data(current);
      await _persistState(current, scope: scope);
    }
  }

  Future<void> clearAll() async {
    final scope = _storageScope(ref.read(authServiceProvider).currentUser?.id);
    state = const AsyncValue.data(FavouritesState());
    await _persistState(const FavouritesState(), scope: scope);
  }
}

/// Global favourites provider (async — loads from disk + remote).
final favouritesProvider =
    AsyncNotifierProvider<FavouritesNotifier, FavouritesState>(
      FavouritesNotifier.new,
    );
