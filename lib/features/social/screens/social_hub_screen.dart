import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/team_model.dart';
import '../../../models/team_supporter_model.dart';
import '../../../providers/teams_provider.dart';
import '../../../providers/currency_provider.dart';
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
  bool _showAddFriend = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            const SocialHeader(),
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
                            ? FriendsTabView(
                                query: _friendQuery,
                                onQueryChanged: (value) =>
                                    setState(() => _friendQuery = value),
                                onAddPressed: () =>
                                    setState(() => _showAddFriend = true),
                                onPoolPressed: _openPoolPrompt,
                                friends: _buildFriendHandles(_friendQuery),
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
            AddFriendWizard(
              isOpen: _showAddFriend,
              onClose: () => setState(() => _showAddFriend = false),
            ),
          ],
        ),
      ),
    );
  }

  List<FriendHandle> _buildFriendHandles(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    const friends = <FriendHandle>[
      FriendHandle(fanId: '449012', accuracy: '72%', isOnline: true),
      FriendHandle(fanId: '818312', accuracy: '65%', isOnline: false),
      FriendHandle(fanId: '191021', accuracy: '81%', isOnline: true),
      FriendHandle(fanId: '677102', accuracy: '54%', isOnline: false),
    ];
    return friends
        .where(
          (friend) =>
              normalizedQuery.isEmpty ||
              friend.fanId.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
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
          points: _formatPoints(index),
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
          points: _formatPoints(currentRank),
          isMe: true,
        ),
      );
    }

    return topRows;
  }

  String _formatPoints(int index) {
    final value = 14200 - (index * 350);
    if (value <= 0) return '1,250';
    final whole = value.toString();
    return whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  Future<void> _openPoolPrompt(FriendHandle friend) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PoolPromptSheet(friend: friend),
    );
  }
}
