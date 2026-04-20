import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/team_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

// ──────────────────────────────────────────────
// Data models
// ──────────────────────────────────────────────

class FriendHandle {
  const FriendHandle({required this.name, required this.subtitle, this.poolId});

  final String name;
  final String subtitle;
  final String? poolId;
}

class FanBoardEntry {
  const FanBoardEntry({
    required this.rank,
    required this.label,
    required this.meta,
    required this.isMe,
  });

  final int rank;
  final String label;
  final String meta;
  final bool isMe;
}

// ──────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────

class SocialHeader extends StatelessWidget {
  const SocialHeader({
    super.key,
    required this.muted,
    required this.textColor,
    required this.onBack,
  });

  final Color muted;
  final Color textColor;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
            .withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(LucideIcons.chevronLeft, color: textColor),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Community',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Social Hub',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tab bar
// ──────────────────────────────────────────────

enum SocialTab { friends, clubFanZone }

class SocialTabBar extends StatelessWidget {
  const SocialTabBar({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  final SocialTab activeTab;
  final ValueChanged<SocialTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
      child: Row(
        children: [
          _TabButton(
            label: 'Friends',
            selected: activeTab == SocialTab.friends,
            onTap: () => onChanged(SocialTab.friends),
          ),
          _TabButton(
            label: 'Club Fan Zone',
            selected: activeTab == SocialTab.clubFanZone,
            onTap: () => onChanged(SocialTab.clubFanZone),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? FzColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
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
// Friends tab view
// ──────────────────────────────────────────────

class FriendsTabView extends StatelessWidget {
  const FriendsTabView({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onAddPressed,
    required this.friends,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAddPressed;
  final List<FriendHandle> friends;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SearchField(
                hintText: 'Search friends...',
                onChanged: onQueryChanged,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onAddPressed,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: FzColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FzColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  LucideIcons.userPlus,
                  size: 20,
                  color: FzColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: FzCard(
            borderRadius: 28,
            padding: EdgeInsets.zero,
            child: friends.isEmpty
                ? StateView.empty(
                    title: 'No friends in play yet',
                    subtitle:
                        'Open community pools will appear here once creators start hosting them.',
                    icon: LucideIcons.users,
                  )
                : ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, separatorIndex) => Divider(
                      height: 1,
                      indent: 76,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                    itemBuilder: (context, index) =>
                        FriendRow(friend: friends[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(
            LucideIcons.search,
            size: 18,
            color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class FriendRow extends StatelessWidget {
  const FriendRow({super.key, required this.friend});

  final FriendHandle friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('👤', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  friend.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: friend.poolId == null
                ? null
                : () => context.push('/pool/${friend.poolId}'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: FzColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.swords, size: 14, color: FzColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Pool',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FzColors.primary,
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

// ──────────────────────────────────────────────
// Club Fan Zone view
// ──────────────────────────────────────────────

class ClubFanZoneView extends StatelessWidget {
  const ClubFanZoneView({
    super.key,
    required this.team,
    required this.fanId,
    required this.fanRows,
    required this.fanLoadError,
    this.onRetry,
  });

  final TeamModel? team;
  final String? fanId;
  final List<FanBoardEntry> fanRows;
  final bool fanLoadError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return StateView.empty(
        title: 'Support a club to unlock the fan zone',
        subtitle:
            'Join a membership first, then come back for your club leaderboard.',
        icon: LucideIcons.shield,
      );
    }

    if (fanLoadError) {
      return StateView.error(
        title: 'Could not load the fan zone',
        subtitle: 'Please try again to reload recent supporter activity.',
        onRetry: onRetry,
      );
    }

    if (fanRows.isEmpty) {
      return StateView.empty(
        title: 'No supporters yet',
        subtitle:
            'Recent supporters will appear here once fans start joining this club.',
        icon: LucideIcons.trophy,
      );
    }

    final rows = fanRows;
    FanBoardEntry? myRow;
    for (final row in rows) {
      if (row.isMe) {
        myRow = row;
        break;
      }
    }
    final rank = myRow?.rank;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkSurface2
                    : FzColors.lightSurface2,
                Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkSurface3
                    : FzColors.lightSurface3,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkBorder
                  : FzColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkSurface
                      : FzColors.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? FzColors.darkBorder
                        : FzColors.lightBorder,
                  ),
                ),
                child: Center(
                  child: TeamAvatar(
                    name: team!.name,
                    logoUrl: team!.logoUrl ?? team!.crestUrl,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(team!.shortName ?? team!.name).toUpperCase()} FANS',
                      style: FzTypography.display(
                        size: 28,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? FzColors.darkText
                            : FzColors.lightText,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rank == null
                          ? 'Recent supporter activity for ${team!.shortName ?? team!.name}.'
                          : 'You appear at #$rank in the recent supporter roll.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? FzColors.darkMuted
                            : FzColors.lightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'SUPPORTER ROLL',
          style: FzTypography.display(
            size: 22,
            color: Theme.of(context).brightness == Brightness.dark
                ? FzColors.darkText
                : FzColors.lightText,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FzCard(
            borderRadius: 28,
            padding: EdgeInsets.zero,
            child: ListView.separated(
              itemCount: rows.length + (rows.length > 3 ? 1 : 0),
              separatorBuilder: (_, separatorIndex) => Divider(
                height: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkBorder
                    : FzColors.lightBorder,
              ),
              itemBuilder: (context, index) {
                if (rows.length > 3 && index == 3) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? FzColors.darkSurface3.withValues(alpha: 0.45)
                        : FzColors.lightSurface3.withValues(alpha: 0.4),
                    child: Text(
                      '...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? FzColors.darkMuted
                            : FzColors.lightMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  );
                }
                final row = rows.length > 3 && index > 3
                    ? rows.last
                    : rows[index];
                return _FanLeaderboardRow(row: row);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FanLeaderboardRow extends StatelessWidget {
  const _FanLeaderboardRow({required this.row});

  final FanBoardEntry row;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: row.isMe ? FzColors.primary.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${row.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: row.rank <= 3
                    ? FzColors.coral
                    : Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkMuted
                    : FzColors.lightMuted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkSurface3
                  : FzColors.lightSurface3,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('👤', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              row.isMe ? '${row.label} (You)' : row.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: row.isMe ? FzColors.primary : null,
              ),
            ),
          ),
          Text(
            row.meta,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FzColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}
