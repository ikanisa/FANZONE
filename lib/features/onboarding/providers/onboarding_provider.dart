import 'package:flutter_riverpod/flutter_riverpod.dart';

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
