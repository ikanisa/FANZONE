import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/team_search_database.dart';

// ─────────────────────────────────────────────────────────────
// Step 3: Market region + event focus
// ─────────────────────────────────────────────────────────────

/// The user's primary launch region during onboarding.
final selectedLaunchRegionProvider = StateProvider<String>((ref) => 'global');

/// The event cycles the user wants prioritised.
final selectedLaunchFocusTagsProvider =
    StateNotifierProvider<_SelectedLaunchFocusNotifier, Set<String>>(
      (ref) => _SelectedLaunchFocusNotifier(),
    );

class _SelectedLaunchFocusNotifier extends StateNotifier<Set<String>> {
  _SelectedLaunchFocusNotifier() : super({});

  void toggle(String tag) {
    if (state.contains(tag)) {
      state = {...state}..remove(tag);
    } else {
      state = {...state, tag};
    }
  }

  bool isSelected(String tag) => state.contains(tag);

  void replaceAll(Set<String> tags) => state = {...tags};
}

// ─────────────────────────────────────────────────────────────
// Step 5: Local favorite team
// ─────────────────────────────────────────────────────────────

/// Current search query for local team search (Step 5).
final localTeamSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered search results for local team (Step 5). Max 10.
final localTeamSearchResultsProvider = Provider<List<OnboardingTeam>>((ref) {
  final query = ref.watch(localTeamSearchQueryProvider);
  return searchTeams(query, limit: 10);
});

/// The single selected local team (nullable).
final selectedLocalTeamProvider = StateProvider<OnboardingTeam?>((ref) => null);

// ─────────────────────────────────────────────────────────────
// Step 6: Global clubs
// ─────────────────────────────────────────────────────────────

/// Current search query for popular/extended search (Step 6).
final popularTeamSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered search results for popular team search (Step 6). Max 10.
final popularTeamSearchResultsProvider = Provider<List<OnboardingTeam>>((ref) {
  final query = ref.watch(popularTeamSearchQueryProvider);
  return searchTeams(query, limit: 10);
});

/// The single selected popular team (nullable).
final selectedPopularTeamProvider = StateProvider<OnboardingTeam?>(
  (ref) => null,
);
