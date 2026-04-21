import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../../../models/match_model.dart';
import '../../../theme/colors.dart';
import '../../../widgets/match/match_list_widgets.dart';

// ──────────────────────────────────────────────
// Toolbar widgets
// ──────────────────────────────────────────────

class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.muted,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            ),
          ),
          child: Icon(icon, size: 18, color: muted),
        ),
      ),
    );
  }
}

class FixtureStateChip extends StatelessWidget {
  const FixtureStateChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? FzColors.darkText : FzColors.lightText)
                : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? FzColors.darkBg : muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Primary view toggle
// ──────────────────────────────────────────────

enum FixturesPrimaryView { competitions, matches }

class PrimaryViewToggle extends StatelessWidget {
  const PrimaryViewToggle({
    super.key,
    required this.activeView,
    required this.onSelected,
  });

  final FixturesPrimaryView activeView;
  final ValueChanged<FixturesPrimaryView> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryViewButton(
            icon: LucideIcons.calendar,
            tooltip: 'Matches',
            selected: activeView == FixturesPrimaryView.matches,
            activeColor: FzColors.primary,
            mutedColor: muted,
            onTap: () => onSelected(FixturesPrimaryView.matches),
          ),
          const SizedBox(width: 4),
          _PrimaryViewButton(
            icon: LucideIcons.compass,
            tooltip: 'Competitions',
            selected: activeView == FixturesPrimaryView.competitions,
            activeColor: FzColors.accent2,
            mutedColor: muted,
            onTap: () => onSelected(FixturesPrimaryView.competitions),
          ),
        ],
      ),
    );
  }
}

class _PrimaryViewButton extends StatelessWidget {
  const _PrimaryViewButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.activeColor,
    required this.mutedColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color activeColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      splashRadius: 18,
      style: IconButton.styleFrom(
        backgroundColor: selected ? activeColor : Colors.transparent,
        foregroundColor: selected ? Colors.white : mutedColor,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

// ──────────────────────────────────────────────
// Fixture group card & list item
// ──────────────────────────────────────────────

class FixtureGroupCard extends StatelessWidget {
  const FixtureGroupCard({
    super.key,
    required this.matches,
    required this.onOpenMatch,
    required this.onOpenPools,
  });

  final List<MatchModel> matches;
  final ValueChanged<MatchModel> onOpenMatch;
  final VoidCallback onOpenPools;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < matches.length; index++) ...[
            FixtureListItem(
              match: matches[index],
              onOpenMatch: () => onOpenMatch(matches[index]),
              onOpenPools: onOpenPools,
            ),
            if (index < matches.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: border.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class FixtureListItem extends StatelessWidget {
  const FixtureListItem({
    super.key,
    required this.match,
    required this.onOpenMatch,
    required this.onOpenPools,
  });

  final MatchModel match;
  final VoidCallback onOpenMatch;
  final VoidCallback onOpenPools;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              match.kickoffTimeLocalLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpenMatch,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    _FixtureTeamRow(name: match.homeTeam, textColor: textColor),
                    const SizedBox(height: 10),
                    _FixtureTeamRow(name: match.awayTeam, textColor: textColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              FixtureActionButton(
                tooltip: 'Open match',
                icon: LucideIcons.crosshair,
                color: FzColors.accent2,
                onTap: onOpenMatch,
              ),
              const SizedBox(width: 8),
              FixtureActionButton(
                tooltip: 'Open pools',
                icon: LucideIcons.swords,
                color: FzColors.primary,
                onTap: onOpenPools,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FixtureTeamRow extends StatelessWidget {
  const _FixtureTeamRow({required this.name, required this.textColor});

  final String name;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isDark ? FzColors.darkBg : FzColors.lightBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            ),
          ),
          child: Center(child: TeamAvatar(name: name, size: 14)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class FixtureActionButton extends StatelessWidget {
  const FixtureActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
