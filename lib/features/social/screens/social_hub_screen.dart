import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/pool.dart';
import '../../../models/team_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/pool_service.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final poolsAsync = ref.watch(poolServiceProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 68,
        title: _HubAppBarTitle(
          kicker: 'Community',
          title: 'Social Hub',
          textColor: textColor,
          muted: muted,
        ),
      ),
      body: teamsAsync.when(
        data: (teams) {
          final supportedTeams = teams
              .where((team) => supportedIds.contains(team.id))
              .toList();
          final featuredTeams = teams.where((team) => team.isFeatured).toList();
          final TeamModel? activeClub = supportedTeams.isNotEmpty
              ? supportedTeams.first
              : (featuredTeams.isNotEmpty ? featuredTeams.first : null);

          final fanZoneFansAsync = activeClub == null
              ? null
              : ref.watch(teamAnonymousFansProvider(activeClub.id));
          final fanZoneStatsAsync = activeClub == null
              ? null
              : ref.watch(teamCommunityStatsProvider(activeClub.id));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _SocialTabBar(
                activeTab: _activeTab,
                onChanged: (tab) => setState(() => _activeTab = tab),
              ),
              const SizedBox(height: 20),
              if (_activeTab == _SocialTab.friends) ...[
                _FriendsSearchCard(
                  onChanged: (value) => setState(() => _friendQuery = value),
                  onAddPressed: () => context.go('/predict'),
                ),
                const SizedBox(height: 16),
                poolsAsync.when(
                  data: (pools) {
                    final openPools =
                        pools.where((pool) => pool.status == 'open').toList()
                          ..sort((a, b) => a.lockAt.compareTo(b.lockAt));
                    final friends = _buildFriendHandles(
                      openPools,
                      _friendQuery,
                      currency,
                    );

                    if (friends.isEmpty) {
                      return StateView.empty(
                        title: 'No community challenges found',
                        subtitle:
                            'Open Predict to create the next matchday rivalry.',
                        icon: LucideIcons.users,
                      );
                    }

                    return FzCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < friends.length; i++) ...[
                            _FriendRow(
                              friend: friends[i],
                              onChallenge: friends[i].poolId == null
                                  ? null
                                  : () => context.push(
                                      '/predict/pool/${friends[i].poolId}',
                                    ),
                            ),
                            if (i < friends.length - 1)
                              Divider(
                                height: 1,
                                indent: 72,
                                color: muted.withValues(alpha: 0.18),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => StateView.error(
                    title: 'Could not load social feed',
                    onRetry: () => ref.invalidate(poolServiceProvider),
                  ),
                ),
              ] else ...[
                if (activeClub == null)
                  StateView.empty(
                    title: 'No club fan zone yet',
                    subtitle:
                        'Support a club first to unlock its anonymous supporter leaderboard.',
                    icon: LucideIcons.messagesSquare,
                  )
                else ...[
                  fanZoneStatsAsync?.when(
                        data: (stats) => _ClubFanZoneHero(
                          team: activeClub,
                          fanCount: stats?.fanCount ?? activeClub.fanCount,
                        ),
                        loading: () => _ClubFanZoneHero(
                          team: activeClub,
                          fanCount: activeClub.fanCount,
                        ),
                        error: (error, stackTrace) => _ClubFanZoneHero(
                          team: activeClub,
                          fanCount: activeClub.fanCount,
                        ),
                      ) ??
                      _ClubFanZoneHero(
                        team: activeClub,
                        fanCount: activeClub.fanCount,
                      ),
                  const SizedBox(height: 20),
                  const _SectionHeader(title: 'Fan Leaderboard'),
                  const SizedBox(height: 10),
                  fanZoneFansAsync?.when(
                        data: (fans) => _FanLeaderboardCard(
                          fanIds: fans
                              .map((fan) => fan.anonymousFanId)
                              .toList(growable: false),
                          currentFanId: fanId,
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, stackTrace) => StateView.error(
                          title: 'Could not load fan leaderboard',
                          onRetry: () => ref.invalidate(
                            teamAnonymousFansProvider(activeClub.id),
                          ),
                        ),
                      ) ??
                      const SizedBox.shrink(),
                ],
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => StateView.error(
          title: 'Could not load social hub',
          onRetry: () => ref.invalidate(teamsProvider),
        ),
      ),
    );
  }

  List<_FriendHandle> _buildFriendHandles(
    List<ScorePool> pools,
    String query,
    String currency,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    final handles = <String>{};
    final friends = <_FriendHandle>[];
    final timeFormat = DateFormat.Hm();

    for (final pool in pools) {
      final normalizedName = pool.creatorName.trim().toLowerCase();
      if (!handles.add(normalizedName)) continue;
      if (normalizedQuery.isNotEmpty &&
          !normalizedName.contains(normalizedQuery)) {
        continue;
      }
      friends.add(
        _FriendHandle(
          name: pool.creatorName,
          subtitle:
              '${formatFET(pool.stake, currency)} stake · locks ${timeFormat.format(pool.lockAt)}',
          poolId: pool.id,
        ),
      );
    }

    return friends.take(6).toList();
  }
}

class _FriendHandle {
  const _FriendHandle({
    required this.name,
    required this.subtitle,
    this.poolId,
  });

  final String name;
  final String subtitle;
  final String? poolId;
}

class _HubAppBarTitle extends StatelessWidget {
  const _HubAppBarTitle({
    required this.kicker,
    required this.title,
    required this.textColor,
    required this.muted,
  });

  final String kicker;
  final String title;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kicker.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
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
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
      ),
      child: Row(
        children: [
          _SocialTabButton(
            label: 'Friends',
            selected: activeTab == _SocialTab.friends,
            onTap: () => onChanged(_SocialTab.friends),
          ),
          _SocialTabButton(
            label: 'Club Fan Zone',
            selected: activeTab == _SocialTab.clubFanZone,
            onTap: () => onChanged(_SocialTab.clubFanZone),
          ),
        ],
      ),
    );
  }
}

class _SocialTabButton extends StatelessWidget {
  const _SocialTabButton({
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
            border: selected
                ? const Border(
                    bottom: BorderSide(color: FzColors.accent, width: 2),
                  )
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? FzColors.accent : muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsSearchCard extends StatelessWidget {
  const _FriendsSearchCard({
    required this.onChanged,
    required this.onAddPressed,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search pool creators...',
                prefixIcon: Icon(LucideIcons.search, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: onAddPressed,
          icon: const Icon(LucideIcons.userPlus, size: 18),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onChallenge});

  final _FriendHandle friend;
  final VoidCallback? onChallenge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, size: 18),
          ),
          const SizedBox(width: 14),
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
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onChallenge,
            icon: const Icon(LucideIcons.swords, size: 14),
            label: const Text('Challenge'),
          ),
        ],
      ),
    );
  }
}

class _ClubFanZoneHero extends StatelessWidget {
  const _ClubFanZoneHero({required this.team, required this.fanCount});

  final TeamModel team;
  final int fanCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          TeamAvatar(
            name: team.name,
            logoUrl: team.logoUrl ?? team.crestUrl,
            size: 64,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${team.name.toUpperCase()} FANS',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fanCount > 0
                      ? 'You are inside a supporter registry of $fanCount fans.'
                      : 'You are inside the anonymous supporter registry for this club.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FanLeaderboardCard extends StatelessWidget {
  const _FanLeaderboardCard({required this.fanIds, required this.currentFanId});

  final List<String> fanIds;
  final String? currentFanId;

  @override
  Widget build(BuildContext context) {
    if (fanIds.isEmpty) {
      return StateView.empty(
        title: 'No fan rankings yet',
        subtitle:
            'Supporter IDs will appear here as the club registry fills up.',
        icon: LucideIcons.trophy,
      );
    }

    final topFans = fanIds.take(3).toList();
    final myRank = currentFanId == null
        ? null
        : fanIds.indexWhere((fanId) => fanId == currentFanId);

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < topFans.length; i++) ...[
            _FanRow(
              rank: i + 1,
              fanId: topFans[i],
              isMe: topFans[i] == currentFanId,
            ),
            if (i < topFans.length - 1) const Divider(height: 1, indent: 48),
          ],
          if (fanIds.length > 4)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              child: Text(
                '...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkMuted
                      : FzColors.lightMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          if (currentFanId != null && (myRank ?? -1) >= 3) ...[
            _FanRow(rank: (myRank ?? 0) + 1, fanId: currentFanId!, isMe: true),
          ],
        ],
      ),
    );
  }
}

class _FanRow extends StatelessWidget {
  const _FanRow({required this.rank, required this.fanId, required this.isMe});

  final int rank;
  final String fanId;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final highlight = isMe
        ? FzColors.accent.withValues(alpha: 0.08)
        : Colors.transparent;

    return Container(
      color: highlight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: rank <= 3 ? FzColors.amber : muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '$fanId (You)' : fanId,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isMe ? FzColors.accent : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: FzTypography.sectionLabel(Theme.of(context).brightness),
    );
  }
}
