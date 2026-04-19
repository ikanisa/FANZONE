import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/team_crest.dart';

class OnboardingSelectedTeamCard extends StatelessWidget {
  const OnboardingSelectedTeamCard({
    super.key,
    required this.team,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.helperText,
  });

  final OnboardingTeam team;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FzColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FzColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR SELECTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: FzColors.accent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          OnboardingTeamTile(
            team: team,
            textColor: textColor,
            muted: muted,
            isDark: isDark,
            selected: true,
            onTap: null,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              helperText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingTeamTile extends StatelessWidget {
  const OnboardingTeamTile({
    super.key,
    required this.team,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  final OnboardingTeam team;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? textColor
                : (isDark ? FzColors.darkSurface : FzColors.lightSurface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? textColor.withValues(alpha: 0.2)
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
          ),
          child: Row(
            children: [
              selected
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isDark ? FzColors.darkBg : FzColors.lightBg)
                            .withValues(alpha: 0.12),
                        border: Border.all(
                          color: (isDark ? FzColors.darkBg : FzColors.lightBg)
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        team.shortName.substring(
                          0,
                          team.shortName.length >= 2 ? 2 : 1,
                        ).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? FzColors.darkBg : FzColors.lightBg,
                        ),
                      ),
                    )
                  : TeamCrest(
                      label: team.name,
                      size: 36,
                      backgroundColor: isDark
                          ? FzColors.darkSurface2
                          : FzColors.lightSurface2,
                      borderColor: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  team.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (isDark ? FzColors.darkBg : FzColors.lightBg)
                        : textColor,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  LucideIcons.shieldCheck,
                  size: 18,
                  color: isDark ? FzColors.darkBg : FzColors.lightBg,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPopularTeamCard extends StatelessWidget {
  const OnboardingPopularTeamCard({
    super.key,
    required this.team,
    required this.selected,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onTap,
  });

  final OnboardingTeam team;
  final bool selected;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? FzColors.accent.withValues(alpha: 0.08)
                : (isDark ? FzColors.darkSurface : FzColors.lightSurface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? FzColors.accent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10),
          child: Tooltip(
            message: team.name,
            child: TeamCrest(
              label: team.name,
              size: 32,
              backgroundColor: isDark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderColor: isDark
                  ? FzColors.darkBorder
                  : FzColors.lightBorder,
            ),
          ),
        ),
      ),
    );
  }
}
