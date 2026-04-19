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
    required this.onRemove,
  });

  final OnboardingTeam team;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onRemove;

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
          Text(
            'YOUR SELECTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          OnboardingTeamTile(
            team: team,
            textColor: textColor,
            muted: muted,
            isDark: isDark,
            selected: true,
            onTap: onRemove,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRemove,
            child: const Text('Choose another team'),
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
  final VoidCallback onTap;

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
                ? FzColors.accent.withValues(alpha: 0.12)
                : (isDark ? FzColors.darkSurface : FzColors.lightSurface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? FzColors.accent.withValues(alpha: 0.28)
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
          ),
          child: Row(
            children: [
              TeamCrest(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${team.country}${team.league == null ? '' : ' · ${team.league}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  LucideIcons.shieldCheck,
                  size: 18,
                  color: FzColors.accent,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? FzColors.accent.withValues(alpha: 0.12)
                : (isDark ? FzColors.darkSurface : FzColors.lightSurface),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? FzColors.accent.withValues(alpha: 0.28)
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamCrest(
                label: team.name,
                size: 38,
                backgroundColor: isDark
                    ? FzColors.darkSurface2
                    : FzColors.lightSurface2,
                borderColor: isDark
                    ? FzColors.darkBorder
                    : FzColors.lightBorder,
              ),
              const SizedBox(height: 10),
              Text(
                team.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                team.country,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
