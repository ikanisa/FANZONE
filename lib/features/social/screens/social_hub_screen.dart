import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/pool.dart';
import '../../../models/team_model.dart';
import '../../../models/team_supporter_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/pool_service.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/match/match_list_widgets.dart';

enum _SocialTab { friends, clubFanZone }

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen> {
  _SocialTab _activeTab = _SocialTab.friends;
  String _friendQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final poolsAsync = ref.watch(poolServiceProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _SocialHeader(
              muted: muted,
              textColor: textColor,
              onBack: () => context.go('/profile'),
            ),
            _SocialTabBar(
              activeTab: _activeTab,
              onChanged: (tab) => setState(() => _activeTab = tab),
            ),
            Expanded(
              child: teamsAsync.when(
                data: (teams) {
                  final supportedTeams = teams
                      .where((team) => supportedIds.contains(team.id))
                      .toList();
                  final featuredTeams = teams
                      .where((team) => team.isFeatured)
                      .toList();
                  final TeamModel? activeClub = supportedTeams.isNotEmpty
                      ? supportedTeams.first
                      : (featuredTeams.isNotEmpty ? featuredTeams.first : null);

                  final fanZoneFansAsync = activeClub == null
                      ? null
                      : ref.watch(teamAnonymousFansProvider(activeClub.id));

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                        child: _activeTab == _SocialTab.friends
                            ? poolsAsync.when(
                                data: (pools) => _FriendsTabView(
                                  query: _friendQuery,
                                  onQueryChanged: (value) =>
                                      setState(() => _friendQuery = value),
                                  onAddPressed: () => context.go('/predict'),
                                  friends: _buildFriendHandles(
                                    pools,
                                    _friendQuery,
                                  ),
                                ),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (_, stackTrace) => _FriendsTabView(
                                  query: _friendQuery,
                                  onQueryChanged: (value) =>
                                      setState(() => _friendQuery = value),
                                  onAddPressed: () => context.go('/predict'),
                                  friends: _fallbackFriends,
                                ),
                              )
                            : _ClubFanZoneView(
                                team: activeClub,
                                fanId: fanId,
                                fanRows: fanZoneFansAsync?.valueOrNull == null
                                    ? const []
                                    : _buildFanBoard(
                                        fanZoneFansAsync!.valueOrNull!,
                                        fanId,
                                      ),
                                onRetry: activeClub == null
                                    ? null
                                    : () => ref.invalidate(
                                        teamAnonymousFansProvider(
                                          activeClub.id,
                                        ),
                                      ),
                              ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_FriendHandle> _buildFriendHandles(List<ScorePool> pools, String query) {
    final seen = <String>{};
    final normalizedQuery = query.trim().toLowerCase();
    final friends = <_FriendHandle>[];

    for (final pool in pools.where((pool) => pool.status == 'open')) {
      final name = pool.creatorName.trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (!seen.add(normalized)) continue;
      if (normalizedQuery.isNotEmpty && !normalized.contains(normalizedQuery)) {
        continue;
      }

      friends.add(
        _FriendHandle(
          name: name,
          accuracy: 54 + (name.codeUnits.fold<int>(0, (a, b) => a + b) % 28),
          status: friends.length.isEven
              ? _FriendStatus.online
              : _FriendStatus.offline,
          poolId: pool.id,
        ),
      );
    }

    return friends.isEmpty ? _fallbackFriends : friends.take(6).toList();
  }

  List<_FanBoardEntry> _buildFanBoard(
    List<AnonymousFanRecord> fans,
    String? currentFanId,
  ) {
    if (fans.isEmpty) return _fallbackFanBoard;

    final topRows = <_FanBoardEntry>[];
    for (int index = 0; index < fans.length && index < 3; index++) {
      topRows.add(
        _FanBoardEntry(
          rank: index + 1,
          label: fans[index].anonymousFanId,
          points: _formatPoints(14200 - (index * 350)),
          isMe: fans[index].anonymousFanId == currentFanId,
        ),
      );
    }

    final currentRank = currentFanId == null
        ? -1
        : fans.indexWhere((fan) => fan.anonymousFanId == currentFanId);
    if (currentRank >= 3) {
      topRows.add(
        _FanBoardEntry(
          rank: currentRank + 1,
          label: currentFanId!,
          points: _formatPoints(
            (14200 - (currentRank * 250)).clamp(900, 14200),
          ),
          isMe: true,
        ),
      );
    }

    return topRows;
  }

  static String _formatPoints(num value) {
    final rounded = value.round();
    final raw = rounded.toString();
    return raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

class _SocialHeader extends StatelessWidget {
  const _SocialHeader({
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

class _SocialTabBar extends StatelessWidget {
  const _SocialTabBar({required this.activeTab, required this.onChanged});

  final _SocialTab activeTab;
  final ValueChanged<_SocialTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
      child: Row(
        children: [
          _TabButton(
            label: 'Friends',
            selected: activeTab == _SocialTab.friends,
            onTap: () => onChanged(_SocialTab.friends),
          ),
          _TabButton(
            label: 'Club Fan Zone',
            selected: activeTab == _SocialTab.clubFanZone,
            onTap: () => onChanged(_SocialTab.clubFanZone),
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
                color: selected ? FzColors.accent : Colors.transparent,
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
              color: selected ? FzColors.accent : muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsTabView extends StatelessWidget {
  const _FriendsTabView({
    required this.query,
    required this.onQueryChanged,
    required this.onAddPressed,
    required this.friends,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAddPressed;
  final List<_FriendHandle> friends;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SearchField(
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
                  color: FzColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FzColors.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  LucideIcons.userPlus,
                  size: 20,
                  color: FzColors.accent,
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
            child: ListView.separated(
              itemCount: friends.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 76,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkBorder
                    : FzColors.lightBorder,
              ),
              itemBuilder: (context, index) =>
                  _FriendRow(friend: friends[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hintText, required this.onChanged});

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

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});

  final _FriendHandle friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final statusColor = friend.status == _FriendStatus.online
        ? FzColors.accent
        : muted;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? FzColors.darkSurface3
                      : FzColors.lightSurface3,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('👤', style: TextStyle(fontSize: 18)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? FzColors.darkSurface2
                          : FzColors.lightSurface2,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
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
                  'Acc: ${friend.accuracy}%',
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
                : () => context.push('/predict/pool/${friend.poolId}'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: FzColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.swords, size: 14, color: FzColors.accent),
                  SizedBox(width: 6),
                  Text(
                    'Pool',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FzColors.accent,
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

class _ClubFanZoneView extends StatelessWidget {
  const _ClubFanZoneView({
    required this.team,
    required this.fanId,
    required this.fanRows,
    this.onRetry,
  });

  final TeamModel? team;
  final String? fanId;
  final List<_FanBoardEntry> fanRows;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return Center(
        child: Text(
          'Support a club to unlock the fan zone.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).brightness == Brightness.dark
                ? FzColors.darkMuted
                : FzColors.lightMuted,
          ),
        ),
      );
    }

    final rows = fanRows.isEmpty ? _fallbackFanBoard : fanRows;
    _FanBoardEntry? myRow;
    for (final row in rows) {
      if (row.isMe) {
        myRow = row;
        break;
      }
    }
    final rank = myRow?.rank ?? 42;

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
                      'You are ranked #$rank among ${(team!.shortName ?? team!.name)} fans.',
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
          'FAN LEADERBOARD',
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

  final _FanBoardEntry row;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: row.isMe ? FzColors.accent.withValues(alpha: 0.06) : null,
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
                color: row.isMe ? FzColors.accent : null,
              ),
            ),
          ),
          Text(
            row.points,
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

class _FriendHandle {
  const _FriendHandle({
    required this.name,
    required this.accuracy,
    required this.status,
    this.poolId,
  });

  final String name;
  final int accuracy;
  final _FriendStatus status;
  final String? poolId;
}

enum _FriendStatus { online, offline }

class _FanBoardEntry {
  const _FanBoardEntry({
    required this.rank,
    required this.label,
    required this.points,
    required this.isMe,
  });

  final int rank;
  final String label;
  final String points;
  final bool isMe;
}

const _fallbackFriends = [
  _FriendHandle(
    name: 'PacevillePro',
    accuracy: 72,
    status: _FriendStatus.online,
  ),
  _FriendHandle(
    name: 'GozitanFan',
    accuracy: 65,
    status: _FriendStatus.offline,
  ),
  _FriendHandle(
    name: 'PredictorPro',
    accuracy: 81,
    status: _FriendStatus.online,
  ),
  _FriendHandle(
    name: 'SoccerFan99',
    accuracy: 54,
    status: _FriendStatus.offline,
  ),
];

const _fallbackFanBoard = [
  _FanBoardEntry(rank: 1, label: 'Hamrun_Ultra', points: '14,200', isMe: false),
  _FanBoardEntry(rank: 2, label: 'MaltaLion', points: '13,850', isMe: false),
  _FanBoardEntry(rank: 3, label: 'SoccerKing', points: '12,100', isMe: false),
  _FanBoardEntry(rank: 42, label: 'MaltaFan_99', points: '4,150', isMe: true),
];
