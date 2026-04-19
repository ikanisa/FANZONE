import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/team_contribution_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/fan_identity_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/team/team_widgets.dart';

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
        title: _HubAppBarTitle(
          kicker: 'Fan Clubs',
          title: 'Membership Hub',
          textColor: textColor,
          muted: muted,
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
                _DigitalMembershipCard(
                  activeClub: activeClub,
                  fanId: fanId,
                  membershipTier: membershipTier,
                  clubSplit: clubSplit,
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
                  _MembershipDetailsCard(
                    activeClub: activeClub,
                    membershipTier: membershipTier,
                    clubSplit: clubSplit,
                    levelLabel: fanProfile != null
                        ? 'Lv.${fanProfile.currentLevel}'
                        : 'Supporter',
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
                  contributionsAsync.when(
                    data: (contributions) => _ContributionHistoryList(
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
                  Column(
                    children: [
                      for (var i = 0; i < supportedTeams.length; i++) ...[
                        SupportedTeamCard(
                          team: supportedTeams[i],
                          index: i,
                          onTap: () => context.push(
                            '/clubs/team/${supportedTeams[i].id}',
                          ),
                        ),
                        if (i < supportedTeams.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
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
                  Column(
                    children: [
                      for (var i = 0; i < filteredTeams.length; i++) ...[
                        if (supportedIds.contains(filteredTeams[i].id))
                          SupportedTeamCard(
                            team: filteredTeams[i],
                            index: i,
                            onTap: () => context.push(
                              '/clubs/team/${filteredTeams[i].id}',
                            ),
                          )
                        else
                          TeamCard(
                            team: filteredTeams[i],
                            index: i,
                            onTap: () => context.push(
                              '/clubs/team/${filteredTeams[i].id}',
                            ),
                          ),
                        if (i < filteredTeams.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
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
          _MembershipTabButton(
            label: 'My Clubs',
            selected: filter == _MembershipFilter.myClubs,
            onTap: () => onChanged(_MembershipFilter.myClubs),
          ),
          _MembershipTabButton(
            label: 'Malta',
            selected: filter == _MembershipFilter.malta,
            onTap: () => onChanged(_MembershipFilter.malta),
          ),
          _MembershipTabButton(
            label: 'European Fan Clubs',
            selected: filter == _MembershipFilter.european,
            onTap: () => onChanged(_MembershipFilter.european),
          ),
        ],
      ),
    );
  }
}

class _MembershipTabButton extends StatelessWidget {
  const _MembershipTabButton({
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

class _DigitalMembershipCard extends StatelessWidget {
  const _DigitalMembershipCard({
    required this.activeClub,
    required this.fanId,
    required this.membershipTier,
    required this.clubSplit,
  });

  final TeamModel? activeClub;
  final String? fanId;
  final String membershipTier;
  final int clubSplit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white70 : Colors.black54;
    final formattedFanId = fanId == null || fanId!.length < 6
        ? '— — —'
        : '${fanId!.substring(0, 3)} ${fanId!.substring(3)}';

    return FzCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [FzColors.accent, FzColors.violet],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    membershipTier.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                if (activeClub != null)
                  TeamAvatar(
                    name: activeClub!.name,
                    logoUrl: activeClub!.logoUrl ?? activeClub!.crestUrl,
                    size: 42,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              activeClub?.name ?? 'FANZONE Supporter',
              style: FzTypography.display(size: 28, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              activeClub == null
                  ? 'Join a club to activate your supporter registry card.'
                  : (activeClub!.leagueName ??
                        activeClub!.country ??
                        'Supporter registry'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CardStat(label: 'Fan ID', value: formattedFanId),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardStat(
                    label: 'Status',
                    value: activeClub == null ? 'PENDING' : 'ACTIVE',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardStat(label: 'FET Split', value: '$clubSplit%'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipDetailsCard extends StatelessWidget {
  const _MembershipDetailsCard({
    required this.activeClub,
    required this.membershipTier,
    required this.clubSplit,
    required this.levelLabel,
  });

  final TeamModel activeClub;
  final String membershipTier;
  final int clubSplit;
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      padding: const EdgeInsets.all(20),
      borderColor: FzColors.violet.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FzColors.violet.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                membershipTier,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FzColors.violet,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          Row(
            children: [
              TeamAvatar(
                name: activeClub.name,
                logoUrl: activeClub.logoUrl ?? activeClub.crestUrl,
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeClub.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeClub.leagueName ??
                          activeClub.country ??
                          'Supporter registry',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MembershipMetricCard(
                  label: 'Supporter Tier',
                  value: levelLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MembershipMetricCard(
                  label: 'FET to Club',
                  value: '$clubSplit%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/clubs/team/${activeClub.id}'),
                  child: const Text('View Club'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/wallet'),
                  child: const Text('Support With FET'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MembershipMetricCard extends StatelessWidget {
  const _MembershipMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ContributionHistoryList extends StatelessWidget {
  const _ContributionHistoryList({
    required this.contributions,
    required this.membershipTier,
  });

  final List<TeamContributionModel> contributions;
  final String membershipTier;

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return StateView.empty(
        title: 'No verified contributions yet',
        subtitle:
            'Your supporter payments and FET support will appear here once they are recorded.',
        icon: LucideIcons.receipt,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < contributions.length; i++) ...[
          _ContributionHistoryRow(
            contribution: contributions[i],
            membershipTier: membershipTier,
          ),
          if (i < contributions.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ContributionHistoryRow extends StatelessWidget {
  const _ContributionHistoryRow({
    required this.contribution,
    required this.membershipTier,
  });

  final TeamContributionModel contribution;
  final String membershipTier;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final amountLabel = contribution.amountFet != null
        ? 'FET ${contribution.amountFet}'
        : '${contribution.currencyCode ?? 'EUR'} ${contribution.amountMoney?.toStringAsFixed(2) ?? '0.00'}';
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(contribution.createdAt);

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amountLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(date, style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                membershipTier,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FzColors.violet,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                contribution.status.toUpperCase(),
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ],
      ),
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
