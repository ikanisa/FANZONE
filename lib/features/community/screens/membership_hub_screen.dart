import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/team_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/fan_identity_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/team/team_widgets.dart';
import '../widgets/contribution_history_list.dart';
import '../widgets/digital_membership_card.dart';
import '../widgets/membership_details_card.dart';

enum _MembershipFilter { myClubs, malta, european }

class MembershipHubScreen extends ConsumerStatefulWidget {
  const MembershipHubScreen({super.key});

  @override
  ConsumerState<MembershipHubScreen> createState() =>
      _MembershipHubScreenState();
}

class _MembershipHubScreenState extends ConsumerState<MembershipHubScreen> {
  _MembershipFilter _filter = _MembershipFilter.myClubs;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final teamsAsync = ref.watch(teamsProvider);
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final fanProfile = ref.watch(fanProfileProvider).valueOrNull;
    final membershipTier = _membershipTierForLevel(
      fanProfile?.currentLevel ?? 1,
    );
    final clubSplit = _fetSplitForTier(membershipTier);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FAN CLUBS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Membership Hub',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: teamsAsync.when(
        data: (teams) {
          final supportedTeams = teams
              .where((team) => supportedIds.contains(team.id))
              .toList();
          final activeClub = supportedTeams.isNotEmpty
              ? supportedTeams.first
              : null;
          final filteredTeams = _applyFilter(teams, supportedIds, _searchQuery);
          final contributionsAsync = activeClub == null
              ? null
              : ref.watch(teamContributionHistoryProvider(activeClub.id));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _MembershipTabBar(
                filter: _filter,
                onChanged: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 20),
              if (_filter == _MembershipFilter.myClubs) ...[
                _SectionTitleRow(
                  title: 'DIGITAL CARD',
                  actionLabel: fanId == null ? null : 'Share',
                  onAction: fanId == null || activeClub == null
                      ? null
                      : () async {
                          await SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Fan #$fanId is registered with ${activeClub.name} on FANZONE.',
                            ),
                          );
                        },
                ),
                const SizedBox(height: 10),
                RepaintBoundary(
                  child: DigitalMembershipCard(
                    activeClub: activeClub,
                    fanId: fanId,
                    membershipTier: membershipTier,
                    clubSplit: clubSplit,
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitleRow(title: 'MEMBERSHIP DETAILS'),
                const SizedBox(height: 10),
                if (activeClub == null)
                  StateView.empty(
                    title: 'No active memberships yet',
                    subtitle:
                        'Support a club to unlock a digital card, supporter registry entry, and club-linked identity.',
                    icon: LucideIcons.badgeCheck,
                  )
                else
                  RepaintBoundary(
                    child: MembershipDetailsCard(
                      activeClub: activeClub,
                      membershipTier: membershipTier,
                      clubSplit: clubSplit,
                      levelLabel: fanProfile != null
                          ? 'Lv.${fanProfile.currentLevel}'
                          : 'Supporter',
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionTitleRow(title: 'CONTRIBUTION HISTORY'),
                const SizedBox(height: 10),
                if (activeClub == null || contributionsAsync == null)
                  StateView.empty(
                    title: 'No club selected yet',
                    subtitle:
                        'Join a club first to start tracking verified supporter contributions.',
                    icon: LucideIcons.receipt,
                  )
                else
                  RepaintBoundary(
                    child: contributionsAsync.when(
                      data: (contributions) => ContributionHistoryList(
                        contributions: contributions,
                        membershipTier: membershipTier,
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => StateView.error(
                        title: 'Could not load contribution history',
                        onRetry: () => ref.invalidate(
                          teamContributionHistoryProvider(activeClub.id),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _SectionTitleRow(
                  title: 'MY CLUBS',
                  actionLabel: 'Discover',
                  onAction: () => context.push('/clubs/teams'),
                ),
                const SizedBox(height: 10),
                if (supportedTeams.isEmpty)
                  Column(
                    children: [
                      StateView.empty(
                        title: 'No memberships yet',
                        subtitle:
                            'Open club discovery to build your supporter registry.',
                        icon: LucideIcons.users,
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/clubs/teams'),
                        icon: const Icon(LucideIcons.search, size: 16),
                        label: const Text('Discover clubs'),
                      ),
                    ],
                  )
                else
                  RepaintBoundary(
                    child: _ClubList(
                      teams: supportedTeams,
                      supportedIds: supportedIds,
                      onTapTeam: (team) =>
                          context.push('/clubs/team/${team.id}'),
                    ),
                  ),
              ] else ...[
                _DiscoverSearchCard(
                  hintText: 'Search clubs...',
                  categoryLabel: _filter == _MembershipFilter.malta
                      ? 'Malta'
                      : 'European Fan Clubs',
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 16),
                if (filteredTeams.isEmpty)
                  Column(
                    children: [
                      StateView.empty(
                        title: 'No clubs in this segment',
                        subtitle:
                            'Try another search or open club discovery for the wider supporter registry.',
                        icon: LucideIcons.search,
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/clubs/teams'),
                        icon: const Icon(LucideIcons.compass, size: 16),
                        label: const Text('Open club discovery'),
                      ),
                    ],
                  )
                else
                  RepaintBoundary(
                    child: _ClubList(
                      teams: filteredTeams,
                      supportedIds: supportedIds,
                      onTapTeam: (team) =>
                          context.push('/clubs/team/${team.id}'),
                    ),
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => StateView.error(
          title: 'Could not load membership hub',
          onRetry: () => ref.invalidate(teamsProvider),
        ),
      ),
    );
  }

  List<TeamModel> _applyFilter(
    List<TeamModel> teams,
    Set<String> supportedIds,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();

    bool matchesSearch(TeamModel team) {
      if (normalizedQuery.isEmpty) return true;
      return [team.name, team.leagueName, team.country].whereType<String>().any(
        (value) => value.toLowerCase().contains(normalizedQuery),
      );
    }

    String lowerCountry(TeamModel team) => (team.country ?? '').toLowerCase();

    switch (_filter) {
      case _MembershipFilter.myClubs:
        return teams
            .where(
              (team) => supportedIds.contains(team.id) && matchesSearch(team),
            )
            .toList();
      case _MembershipFilter.malta:
        return teams
            .where(
              (team) =>
                  lowerCountry(team).contains('malta') && matchesSearch(team),
            )
            .toList();
      case _MembershipFilter.european:
        return teams
            .where(
              (team) =>
                  !lowerCountry(team).contains('malta') && matchesSearch(team),
            )
            .take(16)
            .toList();
    }
  }

  String _membershipTierForLevel(int level) {
    if (level >= 6) return 'Legend';
    if (level >= 4) return 'Ultra';
    if (level >= 2) return 'Member';
    return 'Supporter';
  }

  int _fetSplitForTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'legend':
        return 35;
      case 'ultra':
        return 20;
      case 'member':
        return 10;
      default:
        return 0;
    }
  }
}

// ── Small private widgets kept inline (not worth separate files) ──

class _ClubList extends StatelessWidget {
  const _ClubList({
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
      separatorBuilder: (_, _) => const SizedBox(height: 8),
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

class _MembershipTabBar extends StatelessWidget {
  const _MembershipTabBar({required this.filter, required this.onChanged});

  final _MembershipFilter filter;
  final ValueChanged<_MembershipFilter> onChanged;

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
            selected: filter == _MembershipFilter.myClubs,
            onTap: () => onChanged(_MembershipFilter.myClubs),
          ),
          _TabButton(
            label: 'Malta',
            selected: filter == _MembershipFilter.malta,
            onTap: () => onChanged(_MembershipFilter.malta),
          ),
          _TabButton(
            label: 'European Fan Clubs',
            selected: filter == _MembershipFilter.european,
            onTap: () => onChanged(_MembershipFilter.european),
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

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
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

class _DiscoverSearchCard extends StatelessWidget {
  const _DiscoverSearchCard({
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
