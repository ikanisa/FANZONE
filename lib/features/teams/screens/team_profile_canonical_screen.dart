import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/competition_model.dart';
import '../../../models/match_model.dart';
import '../../../models/team_contribution_model.dart';
import '../../../models/team_model.dart';
import '../../../models/team_supporter_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/team_crest.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/team/fet_contribution_sheet.dart';

enum _TeamProfileTab { overview, members, fixtures, contribute, about }

class TeamProfileScreen extends ConsumerStatefulWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends ConsumerState<TeamProfileScreen> {
  _TeamProfileTab _activeTab = _TeamProfileTab.overview;

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider(widget.teamId));
    final matchesAsync = ref.watch(teamMatchesProvider(widget.teamId));
    final competitionsAsync = ref.watch(competitionsProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final statsAsync = ref.watch(teamCommunityStatsProvider(widget.teamId));
    final fansAsync = ref.watch(teamAnonymousFansProvider(widget.teamId));
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return teamAsync.when(
      data: (team) {
        if (team == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final competitions =
            competitionsAsync.valueOrNull ?? const <CompetitionModel>[];
        final matches = matchesAsync.valueOrNull ?? const <MatchModel>[];
        final stats = statsAsync.valueOrNull;
        final fans = fansAsync.valueOrNull ?? const <AnonymousFanRecord>[];
        final clubRank = _computeClubRank(teamsAsync.valueOrNull, team.id);
        final isSupported = supportedIds.contains(team.id);
        final primaryCompetition = _resolvePrimaryCompetition(team, competitions);

        return Scaffold(
          backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
          body: SafeArea(
            child: Column(
              children: [
                _TeamProfileHeader(
                  onBack: () => context.go('/clubs/membership'),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _TeamHeroBanner(team: team, competition: primaryCompetition),
                      _TeamInfoSection(
                        team: team,
                        stats: stats,
                        clubRank: clubRank,
                        isSupported: isSupported,
                        isAuthenticated: isAuthenticated,
                        onMembershipTap: () => _handleMembershipTap(
                          context,
                          team,
                          isAuthenticated,
                        ),
                      ),
                      _TeamTabs(
                        activeTab: _activeTab,
                        onChanged: (tab) => setState(() => _activeTab = tab),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                        child: _ActiveTabBody(
                          activeTab: _activeTab,
                          team: team,
                          matches: matches,
                          stats: stats,
                          fans: fans,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, stackTrace) => const Scaffold(body: SizedBox.shrink()),
    );
  }

  CompetitionModel? _resolvePrimaryCompetition(
    TeamModel team,
    List<CompetitionModel> competitions,
  ) {
    for (final id in team.competitionIds) {
      for (final competition in competitions) {
        if (competition.id == id) return competition;
      }
    }
    return null;
  }

  int _computeClubRank(List<TeamModel>? teams, String teamId) {
    if (teams == null || teams.isEmpty) return 1;
    final sorted = [...teams]
      ..sort((a, b) => b.fanCount.compareTo(a.fanCount));
    final index = sorted.indexWhere((team) => team.id == teamId);
    return index >= 0 ? index + 1 : 1;
  }

  Future<void> _handleMembershipTap(
    BuildContext context,
    TeamModel team,
    bool isAuthenticated,
  ) async {
    if (!isAuthenticated) {
      context.go('/login');
      return;
    }
    await ref.read(supportedTeamsServiceProvider.notifier).toggleSupport(team.id);
  }
}

class _TeamProfileHeader extends StatelessWidget {
  const _TeamProfileHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
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
            icon: Icon(Icons.chevron_left_rounded, color: textColor),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Team Profile',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TeamHeroBanner extends StatelessWidget {
  const _TeamHeroBanner({required this.team, required this.competition});

  final TeamModel team;
  final CompetitionModel? competition;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 192,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 176,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A0A00), Color(0xFF2D1100)],
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                (competition?.name ?? team.leagueName ?? 'Club').toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 0,
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkSurface
                    : FzColors.lightSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkSurface2
                      : FzColors.lightSurface2,
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: TeamCrest(
                label: team.name,
                crestUrl: team.crestUrl ?? team.logoUrl,
                size: 72,
                backgroundColor: Colors.transparent,
                borderColor: Colors.transparent,
                borderWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamInfoSection extends StatelessWidget {
  const _TeamInfoSection({
    required this.team,
    required this.stats,
    required this.clubRank,
    required this.isSupported,
    required this.isAuthenticated,
    required this.onMembershipTap,
  });

  final TeamModel team;
  final TeamCommunityStats? stats;
  final int clubRank;
  final bool isSupported;
  final bool isAuthenticated;
  final VoidCallback onMembershipTap;

  @override
  Widget build(BuildContext context) {
    final members = stats?.fanCount ?? team.fanCount;
    final totalFet = stats?.totalFetContributed ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            team.name,
            style: FzTypography.display(
              size: 30,
              color: textColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${team.country ?? 'Club'}${team.leagueName != null ? ' · ${team.leagueName}' : ''}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: _formatCompact(members),
                  label: 'Members',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _StatBox(value: '$clubRank', label: 'Club Rank')),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  value: _formatCompact(totalFet),
                  label: 'Club FET',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _addonTitle(team),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _addonValue(team),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: FzColors.accent,
                    letterSpacing: 2.0,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _addonDescription(team),
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onMembershipTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: FzColors.accent.withValues(alpha: 0.14),
                foregroundColor: FzColors.accent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: FzColors.accent.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isAuthenticated && isSupported
                    ? 'Manage Membership'
                    : 'Join ${team.shortName ?? team.name} Fan Club — Free',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCompact(int value) {
    if (value >= 1000) {
      final compact = value / 1000;
      final display = compact >= 10
          ? compact.toStringAsFixed(1)
          : compact.toStringAsFixed(2);
      return '${display.replaceFirst(RegExp(r'\\.0+$'), '')}K';
    }
    return value.toString();
  }

  String _addonTitle(TeamModel team) {
    if (team.fiatContributionsEnabled) return 'FIAT CONTRIBUTION CHANNEL';
    if (team.fetContributionsEnabled) return 'FET CONTRIBUTION ADD-ON';
    return 'FAN SUPPORT CHANNEL';
  }

  String _addonValue(TeamModel team) {
    if (team.fiatContributionMode != null && team.fiatContributionMode!.isNotEmpty) {
      return team.fiatContributionMode!.toUpperCase().replaceAll('_', ' ');
    }
    if (team.fetContributionsEnabled) return 'FET ENABLED';
    return 'COMING SOON';
  }

  String _addonDescription(TeamModel team) {
    if (team.fiatContributionsEnabled || team.fetContributionsEnabled) {
      return 'Open the contribution flow from the Contribute tab · Verified via Fan ID';
    }
    return 'Contribution channels are not available for this club yet.';
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamTabs extends StatelessWidget {
  const _TeamTabs({required this.activeTab, required this.onChanged});

  final _TeamProfileTab activeTab;
  final ValueChanged<_TeamProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TeamTabButton(
              label: 'Overview',
              selected: activeTab == _TeamProfileTab.overview,
              onTap: () => onChanged(_TeamProfileTab.overview),
            ),
            _TeamTabButton(
              label: 'Members',
              selected: activeTab == _TeamProfileTab.members,
              onTap: () => onChanged(_TeamProfileTab.members),
            ),
            _TeamTabButton(
              label: 'Fixtures',
              selected: activeTab == _TeamProfileTab.fixtures,
              onTap: () => onChanged(_TeamProfileTab.fixtures),
            ),
            _TeamTabButton(
              label: 'Contribute',
              selected: activeTab == _TeamProfileTab.contribute,
              onTap: () => onChanged(_TeamProfileTab.contribute),
            ),
            _TeamTabButton(
              label: 'About',
              selected: activeTab == _TeamProfileTab.about,
              onTap: () => onChanged(_TeamProfileTab.about),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamTabButton extends StatelessWidget {
  const _TeamTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 108,
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
    );
  }
}

class _ActiveTabBody extends StatelessWidget {
  const _ActiveTabBody({
    required this.activeTab,
    required this.team,
    required this.matches,
    required this.stats,
    required this.fans,
  });

  final _TeamProfileTab activeTab;
  final TeamModel team;
  final List<MatchModel> matches;
  final TeamCommunityStats? stats;
  final List<AnonymousFanRecord> fans;

  @override
  Widget build(BuildContext context) {
    switch (activeTab) {
      case _TeamProfileTab.overview:
        return _OverviewTab(matches: matches);
      case _TeamProfileTab.members:
        return _MembersTab(team: team, stats: stats, fans: fans);
      case _TeamProfileTab.fixtures:
        return _FixturesTab(matches: matches);
      case _TeamProfileTab.contribute:
        return _ContributeTab(team: team);
      case _TeamProfileTab.about:
        return _AboutTab(team: team);
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.matches});

  final List<MatchModel> matches;

  @override
  Widget build(BuildContext context) {
    final latestMatch = _resolveLatestMatch(matches);
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATEST MATCH',
          style: FzTypography.display(
            size: 22,
            color: textColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        if (latestMatch == null)
          Text('No match data available yet.', style: TextStyle(fontSize: 13, color: muted))
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkBorder
                    : FzColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MatchSide(label: latestMatch.homeTeam),
                Text(
                  latestMatch.isFinished
                      ? '${latestMatch.ftHome ?? 0} - ${latestMatch.ftAway ?? 0}'
                      : 'VS',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                _MatchSide(label: latestMatch.awayTeam),
              ],
            ),
          ),
      ],
    );
  }

  MatchModel? _resolveLatestMatch(List<MatchModel> matches) {
    if (matches.isEmpty) return null;
    final finished = matches.where((match) => match.isFinished).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (finished.isNotEmpty) return finished.first;
    final upcoming = matches.where((match) => !match.isFinished).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }
}

class _MatchSide extends StatelessWidget {
  const _MatchSide({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final short = label.length > 3 ? label.substring(0, 3).toUpperCase() : label.toUpperCase();
    return Column(
      children: [
        const Text('⚽', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(short, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.team,
    required this.stats,
    required this.fans,
  });

  final TeamModel team;
  final TeamCommunityStats? stats;
  final List<AnonymousFanRecord> fans;

  @override
  Widget build(BuildContext context) {
    final entries = fans.take(5).toList();
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          children: [
            _MemberStatCard(emoji: '👑', value: '${((stats?.fanCount ?? team.fanCount) * 0.01).ceil()}', label: 'Legends'),
            _MemberStatCard(emoji: '🔥', value: '${((stats?.fanCount ?? team.fanCount) * 0.12).ceil()}', label: 'Ultras'),
            _MemberStatCard(emoji: '🏅', value: '${((stats?.fanCount ?? team.fanCount) * 0.31).ceil()}', label: 'Members'),
            _MemberStatCard(emoji: '⚽', value: '${stats?.fanCount ?? team.fanCount}', label: 'Supporters'),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'SUPPORTER REGISTRY',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text('No supporters have joined this registry yet.', style: TextStyle(fontSize: 13, color: muted))
        else
          Column(
            children: [
              for (int index = 0; index < entries.length; index++) ...[
                _SupporterRow(
                  rank: index + 1,
                  fanId: entries[index].anonymousFanId,
                  tier: index == 0 ? 'Legend' : index < 3 ? 'Ultra' : 'Member',
                ),
                if (index < entries.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _MemberStatCard extends StatelessWidget {
  const _MemberStatCard({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupporterRow extends StatelessWidget {
  const _SupporterRow({
    required this.rank,
    required this.fanId,
    required this.tier,
  });

  final int rank;
  final String fanId;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 18, child: Text('$rank', style: TextStyle(fontSize: 12, color: muted))),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('👤', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fanId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(tier, style: const TextStyle(fontSize: 10, color: FzColors.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FixturesTab extends StatelessWidget {
  const _FixturesTab({required this.matches});

  final List<MatchModel> matches;

  @override
  Widget build(BuildContext context) {
    final upcoming = matches.where((match) => !match.isFinished).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    if (upcoming.isEmpty) {
      return Text('No upcoming matches yet.', style: TextStyle(fontSize: 13, color: muted));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING MATCHES',
          style: FzTypography.display(
            size: 22,
            color: textColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        MatchListCard(
          matches: upcoming.take(4).toList(),
          onTapMatch: (match) {},
        ),
      ],
    );
  }
}

class _ContributeTab extends ConsumerWidget {
  const _ContributeTab({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canContribute =
        team.fetContributionsEnabled || team.fiatContributionsEnabled;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTRIBUTION FLOW',
          style: FzTypography.display(
            size: 22,
            color: textColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? FzColors.darkSurface2
                : FzColors.lightSurface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkBorder
                  : FzColors.lightBorder,
            ),
          ),
          child: const Column(
            children: [
              _ContributionStep(
                index: '1',
                title: 'Choose Contribution Method',
                subtitle: 'Use the available FET or fiat flow for this club.',
              ),
              SizedBox(height: 20),
              _ContributionStep(
                index: '2',
                title: 'Complete Payment',
                subtitle: 'Confirm the transfer in the selected payment flow.',
              ),
              SizedBox(height: 20),
              _ContributionStep(
                index: '3',
                title: 'Return to FANZONE',
                subtitle: 'Your supporter status updates after confirmation.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canContribute
                ? () async {
                    if (team.fetContributionsEnabled) {
                      await FETContributionSheet.show(context, team);
                      return;
                    }
                    final link = team.fiatContributionLink;
                    final uri = link == null ? null : Uri.tryParse(link);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00),
              foregroundColor: const Color(0xFF1A1400),
              disabledBackgroundColor: const Color(0xFFFFCC00).withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              canContribute ? 'CONTRIBUTE NOW' : 'CONTRIBUTIONS UNAVAILABLE',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContributionStep extends StatelessWidget {
  const _ContributionStep({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final String index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFCC00).withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFCC00).withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            index,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: Color(0xFFFFCC00),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    final text = (team.description?.trim().isNotEmpty ?? false)
        ? team.description!.trim()
        : '${team.name} is part of ${team.country ?? 'the global football community'} and continues to grow its supporter base through FANZONE.';
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT ${team.shortName ?? team.name}',
          style: FzTypography.display(
            size: 22,
            color: textColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(text, style: TextStyle(fontSize: 14, height: 1.6, color: muted)),
      ],
    );
  }
}
