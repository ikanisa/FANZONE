import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/match_model.dart';
import '../../../models/team_contribution_model.dart';
import '../../../models/team_model.dart';
import '../../../models/team_supporter_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_wordmark.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/team/fet_contribution_sheet.dart';

/// Tab IDs used by the team profile screen.
enum TeamProfileTab { overview, members, fixtures, contribute, about }

/// Horizontal scrollable tab selector.
class TeamProfileTabs extends StatelessWidget {
  const TeamProfileTabs({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  final TeamProfileTab activeTab;
  final ValueChanged<TeamProfileTab> onChanged;

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
              selected: activeTab == TeamProfileTab.overview,
              onTap: () => onChanged(TeamProfileTab.overview),
            ),
            _TeamTabButton(
              label: 'Members',
              selected: activeTab == TeamProfileTab.members,
              onTap: () => onChanged(TeamProfileTab.members),
            ),
            _TeamTabButton(
              label: 'Fixtures',
              selected: activeTab == TeamProfileTab.fixtures,
              onTap: () => onChanged(TeamProfileTab.fixtures),
            ),
            _TeamTabButton(
              label: 'Contribute',
              selected: activeTab == TeamProfileTab.contribute,
              onTap: () => onChanged(TeamProfileTab.contribute),
            ),
            _TeamTabButton(
              label: 'About',
              selected: activeTab == TeamProfileTab.about,
              onTap: () => onChanged(TeamProfileTab.about),
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
    );
  }
}

/// Dispatches the active tab to its body widget.
class TeamProfileTabBody extends StatelessWidget {
  const TeamProfileTabBody({
    super.key,
    required this.activeTab,
    required this.team,
    required this.matches,
    required this.stats,
    required this.fans,
  });

  final TeamProfileTab activeTab;
  final TeamModel team;
  final List<MatchModel> matches;
  final TeamCommunityStats? stats;
  final List<AnonymousFanRecord> fans;

  @override
  Widget build(BuildContext context) {
    switch (activeTab) {
      case TeamProfileTab.overview:
        return TeamOverviewTab(matches: matches);
      case TeamProfileTab.members:
        return TeamMembersTab(team: team, stats: stats, fans: fans);
      case TeamProfileTab.fixtures:
        return TeamFixturesTab(matches: matches);
      case TeamProfileTab.contribute:
        return TeamContributeTab(team: team);
      case TeamProfileTab.about:
        return TeamAboutTab(team: team);
    }
  }
}

// ──────────────────────────────────────────────
// Overview tab
// ──────────────────────────────────────────────

class TeamOverviewTab extends StatelessWidget {
  const TeamOverviewTab({super.key, required this.matches});

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
          Text(
            'No match data available yet.',
            style: TextStyle(fontSize: 13, color: muted),
          )
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
    final short = label.length > 3
        ? label.substring(0, 3).toUpperCase()
        : label.toUpperCase();
    return Column(
      children: [
        const Text('⚽', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          short,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Members tab
// ──────────────────────────────────────────────

class TeamMembersTab extends StatelessWidget {
  const TeamMembersTab({
    super.key,
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
            _MemberStatCard(
              emoji: '👑',
              value: '${((stats?.fanCount ?? team.fanCount) * 0.01).ceil()}',
              label: 'Legends',
            ),
            _MemberStatCard(
              emoji: '🔥',
              value: '${((stats?.fanCount ?? team.fanCount) * 0.12).ceil()}',
              label: 'Ultras',
            ),
            _MemberStatCard(
              emoji: '🏅',
              value: '${((stats?.fanCount ?? team.fanCount) * 0.31).ceil()}',
              label: 'Members',
            ),
            _MemberStatCard(
              emoji: '⚽',
              value: '${stats?.fanCount ?? team.fanCount}',
              label: 'Supporters',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'SUPPORTER REGISTRY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(
            'No supporters have joined this registry yet.',
            style: TextStyle(fontSize: 13, color: muted),
          )
        else
          Column(
            children: [
              for (int index = 0; index < entries.length; index++) ...[
                _SupporterRow(
                  rank: index + 1,
                  fanId: entries[index].anonymousFanId,
                  tier: index == 0
                      ? 'Legend'
                      : index < 3
                      ? 'Ultra'
                      : 'Member',
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
          SizedBox(
            width: 18,
            child: Text('$rank', style: TextStyle(fontSize: 12, color: muted)),
          ),
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
                Text(
                  fanId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tier,
                  style: const TextStyle(fontSize: 10, color: FzColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Fixtures tab
// ──────────────────────────────────────────────

class TeamFixturesTab extends StatelessWidget {
  const TeamFixturesTab({super.key, required this.matches});

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
      return Text(
        'No upcoming matches yet.',
        style: TextStyle(fontSize: 13, color: muted),
      );
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

// ──────────────────────────────────────────────
// Contribute tab
// ──────────────────────────────────────────────

class TeamContributeTab extends ConsumerWidget {
  const TeamContributeTab({super.key, required this.team});

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
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: FzColors.secondary,
              foregroundColor: FzColors.onSecondary,
              disabledBackgroundColor: FzColors.secondary.withValues(
                alpha: 0.35,
              ),
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
            color: FzColors.secondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: FzColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            index,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: FzColors.secondary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: FzWordmark.spansForText(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: FzWordmark.spansForText(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// About tab
// ──────────────────────────────────────────────

class TeamAboutTab extends StatelessWidget {
  const TeamAboutTab({super.key, required this.team});

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
        Text.rich(
          TextSpan(
            children: FzWordmark.spansForText(
              text,
              style: TextStyle(fontSize: 14, height: 1.6, color: muted),
            ),
          ),
        ),
      ],
    );
  }
}
