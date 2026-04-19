import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../theme/colors.dart';
import 'onboarding_step_chrome.dart';
import 'onboarding_team_selection_widgets.dart';

class OnboardingFavoriteTeamStep extends StatelessWidget {
  const OnboardingFavoriteTeamStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.searchController,
    required this.results,
    required this.selectedTeam,
    required this.query,
    required this.onSearchChanged,
    required this.onTeamSelected,
    required this.onBack,
    required this.onNext,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final TextEditingController searchController;
  final List<OnboardingTeam> results;
  final OnboardingTeam? selectedTeam;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<OnboardingTeam> onTeamSelected;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingBackButtonRow(onBack: onBack),
            const SizedBox(height: 8),
            OnboardingSectionTitle(
              title: 'Favorite Team',
              textColor: textColor,
            ),
            const SizedBox(height: 8),
            Text(
              'FANZONE is local, add your local favorite team',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search your local favorite team',
                prefixIcon: Icon(LucideIcons.search, size: 18, color: muted),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: query.trim().isNotEmpty
                  ? _SearchResultsList(
                      results: results,
                      query: query,
                      selectedTeamId: selectedTeam?.id,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      onTeamSelected: onTeamSelected,
                    )
                  : selectedTeam != null
                  ? OnboardingSelectedTeamCard(
                      team: selectedTeam!,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      helperText: 'Search to change your team',
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 48,
                            color: muted.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start typing to find your team',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            OnboardingPrimaryButton(
              label: selectedTeam != null ? 'CONTINUE' : 'SKIP THIS STEP',
              onTap: onNext,
              tone: selectedTeam != null
                  ? OnboardingButtonTone.primary
                  : OnboardingButtonTone.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPopularTeamsStep extends StatelessWidget {
  const OnboardingPopularTeamsStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.searchController,
    required this.query,
    required this.searchResults,
    required this.popularTeams,
    required this.selectedTeam,
    required this.onSearchChanged,
    required this.onSelectTeam,
    required this.onBack,
    required this.onFinish,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final TextEditingController searchController;
  final String query;
  final List<OnboardingTeam> searchResults;
  final List<OnboardingTeam> popularTeams;
  final OnboardingTeam? selectedTeam;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<OnboardingTeam> onSelectTeam;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingBackButtonRow(onBack: onBack),
            const SizedBox(height: 8),
            OnboardingSectionTitle(
              title: 'Popular Teams',
              textColor: textColor,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your favorite',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 20),
                children: [
                  if (selectedTeam != null) ...[
                    OnboardingSelectedTeamCard(
                      team: selectedTeam!,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      helperText: 'Search or select below to change your team',
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (query.trim().isEmpty && selectedTeam == null) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: popularTeams.length > 20
                          ? 20
                          : popularTeams.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        final team = popularTeams[index];
                        return OnboardingPopularTeamCard(
                          team: team,
                          selected: selectedTeam?.id == team.id,
                          isDark: isDark,
                          textColor: textColor,
                          muted: muted,
                          onTap: () => onSelectTeam(team),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Didn\'t find your favorite team? Search more',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search European teams',
                      prefixIcon: Icon(LucideIcons.search, size: 18, color: muted),
                    ),
                  ),
                  if (query.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SearchResultsList(
                      results: searchResults,
                      query: query,
                      selectedTeamId: selectedTeam?.id,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      onTeamSelected: onSelectTeam,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            OnboardingPrimaryButton(
              label: selectedTeam != null ? 'COMPLETE SETUP' : 'SKIP FOR NOW',
              onTap: onFinish,
              tone: selectedTeam != null
                  ? OnboardingButtonTone.primary
                  : OnboardingButtonTone.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.query,
    required this.selectedTeamId,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onTeamSelected,
  });

  final List<OnboardingTeam> results;
  final String query;
  final String? selectedTeamId;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final ValueChanged<OnboardingTeam> onTeamSelected;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No teams found matching "$query"',
            style: TextStyle(fontSize: 13, color: muted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? FzColors.darkSurface2.withValues(alpha: 0.5)
            : FzColors.lightSurface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          for (int index = 0; index < results.length; index++) ...[
            OnboardingTeamTile(
              team: results[index],
              textColor: textColor,
              muted: muted,
              isDark: isDark,
              selected: selectedTeamId == results[index].id,
              onTap: () => onTeamSelected(results[index]),
            ),
            if (index < results.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
