import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/team_model.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/team/team_widgets.dart';

// ──────────────────────────────────────────────
// Filter enum (shared with screen)
// ──────────────────────────────────────────────

enum MembershipFilter { myClubs, malta, european }

// ──────────────────────────────────────────────
// Tab bar
// ──────────────────────────────────────────────

class MembershipTabBar extends StatelessWidget {
  const MembershipTabBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final MembershipFilter filter;
  final ValueChanged<MembershipFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
          bottom: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'My Clubs',
            selected: filter == MembershipFilter.myClubs,
            onTap: () => onChanged(MembershipFilter.myClubs),
          ),
          _TabButton(
            label: 'Malta',
            selected: filter == MembershipFilter.malta,
            onTap: () => onChanged(MembershipFilter.malta),
          ),
          _TabButton(
            label: 'European Fan Clubs',
            selected: filter == MembershipFilter.european,
            onTap: () => onChanged(MembershipFilter.european),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    bottom: BorderSide(color: FzColors.primary, width: 2),
                  )
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? FzColors.primary : muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Section title row
// ──────────────────────────────────────────────

class SectionTitleRow extends StatelessWidget {
  const SectionTitleRow({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Club list
// ──────────────────────────────────────────────

class ClubList extends StatelessWidget {
  const ClubList({
    super.key,
    required this.teams,
    required this.supportedIds,
    required this.onTapTeam,
  });

  final List<TeamModel> teams;
  final Set<String> supportedIds;
  final ValueChanged<TeamModel> onTapTeam;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: teams.length,
      separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final team = teams[index];
        if (supportedIds.contains(team.id)) {
          return SupportedTeamCard(
            team: team,
            index: index,
            onTap: () => onTapTeam(team),
          );
        }
        return TeamCard(team: team, index: index, onTap: () => onTapTeam(team));
      },
    );
  }
}

// ──────────────────────────────────────────────
// Discover search card
// ──────────────────────────────────────────────

class DiscoverSearchCard extends StatelessWidget {
  const DiscoverSearchCard({
    super.key,
    required this.hintText,
    required this.categoryLabel,
    required this.onChanged,
  });

  final String hintText;
  final String categoryLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
