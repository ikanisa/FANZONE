import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
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
    required this.onTeamRemoved,
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
  final VoidCallback onTeamRemoved;
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
            OnboardingSectionTitle(title: 'FAVORITE TEAM', textColor: textColor),
            const SizedBox(height: 8),
            Text(
              'FANZONE is local first. Pick the club closest to your football identity.',
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
              child: selectedTeam != null
                  ? OnboardingSelectedTeamCard(
                      team: selectedTeam!,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      onRemove: onTeamRemoved,
                    )
                  : results.isEmpty || query.trim().isEmpty
                  ? Center(
                      child: Text(
                        'Start typing to find your team',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final team = results[index];
                        return OnboardingTeamTile(
                          team: team,
                          textColor: textColor,
                          muted: muted,
                          isDark: isDark,
                          selected: false,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTeamSelected(team);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            OnboardingPrimaryButton(label: 'CONTINUE', onTap: onNext),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: onNext,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
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
    required this.selectedIds,
    required this.onSearchChanged,
    required this.onToggleTeam,
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
  final Set<String> selectedIds;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggleTeam;
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
            OnboardingSectionTitle(title: 'POPULAR TEAMS', textColor: textColor),
            const SizedBox(height: 8),
            Text(
              'Choose the clubs you want near the top after launch.',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search more teams',
                prefixIcon: Icon(LucideIcons.search, size: 18, color: muted),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: query.trim().isNotEmpty
                  ? searchResults.isEmpty
                        ? Center(
                            child: Text(
                              'No teams found for "$query"',
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: searchResults.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final team = searchResults[index];
                              return OnboardingTeamTile(
                                team: team,
                                textColor: textColor,
                                muted: muted,
                                isDark: isDark,
                                selected: selectedIds.contains(team.id),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onToggleTeam(team.id);
                                },
                              );
                            },
                          )
                  : GridView.builder(
                      itemCount: popularTeams.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.55,
                          ),
                      itemBuilder: (context, index) {
                        final team = popularTeams[index];
                        return OnboardingPopularTeamCard(
                          team: team,
                          selected: selectedIds.contains(team.id),
                          isDark: isDark,
                          textColor: textColor,
                          muted: muted,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onToggleTeam(team.id);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            OnboardingPrimaryButton(label: 'FINISH', onTap: onFinish),
          ],
        ),
      ),
    );
  }
}
