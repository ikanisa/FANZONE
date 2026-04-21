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
    required this.suggestedTeams,
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
  final List<OnboardingTeam> suggestedTeams;
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
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: FzColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: FzColors.primary.withValues(alpha: 0.20),
                ),
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                size: 30,
                color: FzColors.primary,
              ),
            ),
            const SizedBox(height: 22),
            OnboardingSectionTitle(
              title: 'Almost Done',
              textColor: textColor,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              'Your anonymous Fan ID has been generated securely.',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            Text(
              'OPTIONAL: PICK YOUR FAVORITE TEAM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (selectedTeam != null) ...[
                    OnboardingSelectedTeamCard(
                      team: selectedTeam!,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      helperText: 'Search to change your team',
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search teams...',
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: 18,
                          color: muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (query.trim().isNotEmpty)
                    _SearchResultsList(
                      results: results,
                      query: query,
                      selectedTeamId: selectedTeam?.id,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      onTeamSelected: onTeamSelected,
                    )
                  else if (selectedTeam == null)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: suggestedTeams
                          .map(
                            (team) => InkWell(
                              onTap: () => onTeamSelected(team),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? FzColors.darkSurface2
                                      : FzColors.lightSurface2,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isDark
                                        ? FzColors.darkBorder
                                        : FzColors.lightBorder,
                                  ),
                                ),
                                child: Text(
                                  team.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OnboardingPrimaryButton(
              label: selectedTeam != null
                  ? 'ENTER PLATFORM'
                  : 'SKIP & ENTER TO APP',
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
            style: TextStyle(fontSize: 14, color: muted),
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
