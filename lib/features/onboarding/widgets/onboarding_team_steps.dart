part of '../screens/onboarding_screen.dart';

class _FavoriteTeamStep extends ConsumerStatefulWidget {
  const _FavoriteTeamStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onNext,
    required this.onSkip,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  ConsumerState<_FavoriteTeamStep> createState() => _FavoriteTeamStepState();
}

class _FavoriteTeamStepState extends ConsumerState<_FavoriteTeamStep> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(localTeamSearchResultsProvider);
    final selectedTeam = ref.watch(selectedLocalTeamProvider);
    final query = ref.watch(localTeamSearchQueryProvider);
    final hasSelection = selectedTeam != null;
    final showResults = query.isNotEmpty && !hasSelection;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'FAN',
                  style: FzTypography.display(
                    size: 36,
                    color: FzColors.maltaRed,
                    letterSpacing: 3,
                  ),
                ),
                TextSpan(
                  text: 'ZONE',
                  style: FzTypography.display(
                    size: 36,
                    color: widget.textColor,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Home Club',
            style: FzTypography.display(
              size: 28,
              color: widget.textColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick the club closest to your football identity in your market. You can skip this and adjust later.',
            style: TextStyle(fontSize: 14, color: widget.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: widget.isDark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? FzColors.accent.withValues(alpha: 0.5)
                    : widget.isDark
                    ? FzColors.darkBorder
                    : FzColors.lightBorder,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (value) {
                ref.read(localTeamSearchQueryProvider.notifier).state = value;
                if (hasSelection) {
                  ref.read(selectedLocalTeamProvider.notifier).state = null;
                }
              },
              style: TextStyle(
                fontSize: 15,
                color: widget.textColor,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search clubs from Africa, Europe, and North America',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: widget.muted.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 20,
                  color: widget.muted,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: widget.muted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref
                                  .read(localTeamSearchQueryProvider.notifier)
                                  .state =
                              '';
                          ref.read(selectedLocalTeamProvider.notifier).state =
                              null;
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (!showResults && !hasSelection) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Start typing to find your team',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.muted.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (showResults)
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No teams found for "$query"',
                        style: TextStyle(fontSize: 13, color: widget.muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final team = results[index];
                        return _TeamSearchResult(
                          team: team,
                          isDark: widget.isDark,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(selectedLocalTeamProvider.notifier).state =
                                team;
                            _searchController.text = team.name;
                            _focusNode.unfocus();
                          },
                        );
                      },
                    ),
            ),
          if (hasSelection) ...[
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'YOUR SELECTION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.muted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectedTeamCard(
                    team: selectedTeam,
                    isDark: widget.isDark,
                    textColor: widget.textColor,
                    muted: widget.muted,
                    onRemove: () {
                      ref.read(selectedLocalTeamProvider.notifier).state = null;
                      _searchController.clear();
                      ref.read(localTeamSearchQueryProvider.notifier).state =
                          '';
                    },
                  ),
                ],
              ),
            ),
          ],
          if (!showResults && !hasSelection) const Spacer(),
          const SizedBox(height: 16),
          if (hasSelection)
            _PrimaryButton(label: 'CONTINUE', onTap: widget.onNext)
          else
            _SecondaryButton(label: 'SKIP THIS STEP', onTap: widget.onSkip),
        ],
      ),
    );
  }
}

class _PopularTeamsStep extends ConsumerStatefulWidget {
  const _PopularTeamsStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onComplete,
    required this.onSkip,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  ConsumerState<_PopularTeamsStep> createState() => _PopularTeamsStepState();
}

class _PopularTeamsStepState extends ConsumerState<_PopularTeamsStep> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(selectedLaunchRegionProvider);
    final popular = popularTeamsForRegion(region);
    final selectedIds = ref.watch(selectedPopularTeamsProvider);
    final searchQuery = ref.watch(popularTeamSearchQueryProvider);
    final searchResults = ref.watch(popularTeamSearchResultsProvider);
    final hasSelections = selectedIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'GLOBAL CLUBS',
            style: FzTypography.display(
              size: 32,
              color: widget.textColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the global clubs you want near the top after launch',
            style: TextStyle(fontSize: 14, color: widget.muted),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _buildTeamGrid(popular, selectedIds),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Didn't find your favorite team?",
                        style: TextStyle(fontSize: 13, color: widget.muted),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Search more',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FzColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? FzColors.darkSurface2
                        : FzColors.lightSurface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(popularTeamSearchQueryProvider.notifier).state =
                          value;
                    },
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search more teams',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: widget.muted.withValues(alpha: 0.7),
                      ),
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 20,
                        color: widget.muted,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                size: 18,
                                color: widget.muted,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                        .read(
                                          popularTeamSearchQueryProvider
                                              .notifier,
                                        )
                                        .state =
                                    '';
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (searchQuery.isNotEmpty)
                  ...searchResults.map(
                    (team) => _TeamSearchResult(
                      team: team,
                      isDark: widget.isDark,
                      selected: selectedIds.contains(team.id),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(selectedPopularTeamsProvider.notifier)
                            .toggle(team.id);
                      },
                    ),
                  ),
                if (searchQuery.isNotEmpty && searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No teams found for "$searchQuery"',
                        style: TextStyle(fontSize: 13, color: widget.muted),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (hasSelections)
            _PrimaryButton(label: 'COMPLETE SETUP', onTap: widget.onComplete)
          else
            _SecondaryButton(label: 'SKIP FOR NOW', onTap: widget.onSkip),
        ],
      ),
    );
  }

  Widget _buildTeamGrid(List<OnboardingTeam> teams, Set<String> selectedIds) {
    final rows = <Widget>[];
    for (int i = 0; i < teams.length; i += 5) {
      final rowTeams = teams.sublist(
        i,
        i + 5 > teams.length ? teams.length : i + 5,
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rowTeams.map((team) {
              final isSelected = selectedIds.contains(team.id);
              return _TeamGridItem(
                team: team,
                isSelected: isSelected,
                isDark: widget.isDark,
                textColor: widget.textColor,
                muted: widget.muted,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(selectedPopularTeamsProvider.notifier)
                      .toggle(team.id);
                },
              );
            }).toList(),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
