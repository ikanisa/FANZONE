import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/pool.dart';
import '../../../models/team_model.dart';
import '../../../models/team_supporter_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/pool_service.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/state_view.dart';
import '../widgets/social_hub_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen> {
  SocialTab _activeTab = SocialTab.friends;
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
            SocialHeader(
              muted: muted,
              textColor: textColor,
              onBack: () => context.go('/profile'),
            ),
            SocialTabBar(
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
                        child: _activeTab == SocialTab.friends
                            ? poolsAsync.when(
                                data: (pools) => FriendsTabView(
                                  query: _friendQuery,
                                  onQueryChanged: (value) =>
                                      setState(() => _friendQuery = value),
                                  onAddPressed: () => context.go('/pools'),
                                  friends: _buildFriendHandles(
                                    pools,
                                    _friendQuery,
                                  ),
                                ),
                                loading: () =>
                                    const Center(child: FzGlassLoader()),
                                error: (_, _) => StateView.error(
                                  title: 'Could not load friends',
                                  onRetry: () =>
                                      ref.invalidate(poolServiceProvider),
                                ),
                              )
                            : ClubFanZoneView(
                                team: activeClub,
                                fanId: fanId,
                                fanLoadError:
                                    fanZoneFansAsync?.hasError ?? false,
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
                loading: () => const FzGlassLoader(message: 'Syncing...'),
                error: (_, _) => StateView.error(
                  title: 'Could not load social hub',
                  onRetry: () => ref.invalidate(teamsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FriendHandle> _buildFriendHandles(List<ScorePool> pools, String query) {
    final seen = <String>{};
    final normalizedQuery = query.trim().toLowerCase();
    final friends = <FriendHandle>[];

    for (final pool in pools.where((pool) => pool.status == 'open')) {
      final name = pool.creatorName.trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (!seen.add(normalized)) continue;
      if (normalizedQuery.isNotEmpty && !normalized.contains(normalizedQuery)) {
        continue;
      }

      friends.add(
        FriendHandle(
          name: name,
          subtitle:
              '${pool.participantsCount} joined • ${pool.stake} FET stake',
          poolId: pool.id,
        ),
      );
    }

    return friends.take(6).toList();
  }

  List<FanBoardEntry> _buildFanBoard(
    List<AnonymousFanRecord> fans,
    String? currentFanId,
  ) {
    if (fans.isEmpty) return const <FanBoardEntry>[];

    final sortedFans = [...fans]
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    final topRows = <FanBoardEntry>[];
    for (int index = 0; index < sortedFans.length && index < 3; index++) {
      topRows.add(
        FanBoardEntry(
          rank: index + 1,
          label: sortedFans[index].anonymousFanId,
          meta: _formatJoinedAt(sortedFans[index].joinedAt),
          isMe: sortedFans[index].anonymousFanId == currentFanId,
        ),
      );
    }

    final currentRank = currentFanId == null
        ? -1
        : sortedFans.indexWhere((fan) => fan.anonymousFanId == currentFanId);
    if (currentRank >= 3) {
      topRows.add(
        FanBoardEntry(
          rank: currentRank + 1,
          label: currentFanId!,
          meta: _formatJoinedAt(sortedFans[currentRank].joinedAt),
          isMe: true,
        ),
      );
    }

    return topRows;
  }

  static String _formatJoinedAt(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inDays <= 0) {
      return 'Today';
    }
    if (diff.inDays == 1) {
      return '1d ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${value.day}/${value.month}/${value.year}';
  }
}
