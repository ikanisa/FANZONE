part of '../screens/onboarding_screen.dart';

class _TeamGridItem extends StatelessWidget {
  const _TeamGridItem({
    required this.team,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onTap,
  });

  final OnboardingTeam team;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? FzColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: FzColors.accent, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TeamCrest(
              label: team.shortName,
              crestUrl: team.resolvedCrestUrl,
              fallbackEmoji: team.logoEmoji,
              size: 40,
              backgroundColor: isDark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderColor: isSelected
                  ? FzColors.accent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
              borderWidth: 1.5,
              textColor: isSelected ? FzColors.accent : muted,
            ),
            const SizedBox(height: 4),
            Text(
              team.shortName,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isSelected ? FzColors.accent : muted,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSearchResult extends StatelessWidget {
  const _TeamSearchResult({
    required this.team,
    required this.isDark,
    this.selected = false,
    required this.onTap,
  });

  final OnboardingTeam team;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected
              ? FzColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: FzColors.accent.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          children: [
            TeamCrest(
              label: team.shortName,
              crestUrl: team.resolvedCrestUrl,
              fallbackEmoji: team.logoEmoji,
              size: 38,
              backgroundColor: isDark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderColor: selected
                  ? FzColors.accent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
              textColor: selected ? FzColors.accent : muted,
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
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? FzColors.accent
                          : (isDark ? FzColors.darkText : FzColors.lightText),
                    ),
                  ),
                  Text(
                    '${team.country} · ${team.league}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FzColors.accent,
                ),
                child: const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedTeamCard extends StatelessWidget {
  const _SelectedTeamCard({
    required this.team,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onRemove,
  });

  final OnboardingTeam team;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FzColors.accent.withValues(alpha: 0.15),
            FzColors.violet.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FzColors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          TeamCrest(
            label: team.shortName,
            crestUrl: team.resolvedCrestUrl,
            fallbackEmoji: team.logoEmoji,
            size: 64,
            backgroundColor: isDark
                ? FzColors.darkSurface
                : FzColors.lightSurface,
            borderColor: FzColors.accent.withValues(alpha: 0.4),
            borderWidth: 2,
            textColor: FzColors.accent,
          ),
          const SizedBox(height: 12),
          Text(
            team.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${team.country} · ${team.league}',
            style: TextStyle(fontSize: 12, color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: FzColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.x, size: 14, color: FzColors.error),
                  SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FzColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
