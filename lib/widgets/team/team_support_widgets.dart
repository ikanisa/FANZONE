import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/team_contribution_model.dart';
import '../../models/team_model.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../common/fz_animated_entry.dart';
import '../common/fz_card.dart';
import 'team_widget_utils.dart';

class SupportTeamButton extends StatelessWidget {
  const SupportTeamButton({
    super.key,
    required this.isSupported,
    required this.onTap,
    this.compact = false,
  });

  final bool isSupported;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Icon(
            isSupported
                ? LucideIcons.heart
                : LucideIcons.heart,
            key: ValueKey(isSupported),
            size: 22,
            color: isSupported ? FzColors.danger : FzColors.darkMuted,
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: isSupported
              ? FzColors.danger.withValues(alpha: 0.15)
              : FzColors.primary,
          foregroundColor: isSupported ? FzColors.danger : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          isSupported ? LucideIcons.heart : LucideIcons.heart,
          size: 18,
        ),
        label: Text(
          isSupported ? 'Supporting' : 'Support',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class SupporterCounterChip extends StatelessWidget {
  const SupporterCounterChip({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FzColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.users,
            size: 12,
            color: FzColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            formatCompactTeamCount(count),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: FzColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class AnonymousFanBadge extends StatelessWidget {
  const AnonymousFanBadge({
    super.key,
    required this.fanId,
    this.joinedAt,
    this.index = 0,
  });

  final String fanId;
  final DateTime? joinedAt;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzAnimatedEntry(
      index: index,
      child: FzCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FzColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.user,
                  size: 16,
                  color: FzColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fanId, style: FzTypography.scoreCompact()),
                  if (joinedAt != null)
                    Text(
                      'Joined ${formatTeamRelativeTime(joinedAt!)}',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityStatsCard extends StatelessWidget {
  const CommunityStatsCard({super.key, required this.stats});

  final TeamCommunityStats stats;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Total Fans',
              value: formatCompactTeamCount(stats.fanCount),
              icon: LucideIcons.users,
            ),
          ),
          Expanded(
            child: _StatTile(
              label: 'New (30d)',
              value: formatCompactTeamCount(stats.supportersLast30d),
              icon: LucideIcons.trendingUp,
            ),
          ),
          Expanded(
            child: _StatTile(
              label: 'FET Pool',
              value: formatCompactTeamCount(stats.totalFetContributed),
              icon: LucideIcons.coins,
            ),
          ),
        ],
      ),
    );
  }
}

class ContributionCTA extends StatelessWidget {
  const ContributionCTA({
    super.key,
    required this.team,
    this.onFetTap,
    this.onFiatTap,
  });

  final TeamModel team;
  final VoidCallback? onFetTap;
  final VoidCallback? onFiatTap;

  @override
  Widget build(BuildContext context) {
    final hasFet = team.fetContributionsEnabled;
    final hasFiat = team.fiatContributionsEnabled;

    if (!hasFet && !hasFiat) return const SizedBox.shrink();

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUPPORT ${team.shortName ?? team.name}'.toUpperCase(),
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 12),
          if (hasFet)
            _ContributionOption(
              icon: LucideIcons.coins,
              title: 'Contribute FET',
              subtitle: 'Use your Fan Engagement Tokens',
              color: FzColors.secondary,
              onTap: onFetTap,
            ),
          if (hasFet && hasFiat) const SizedBox(height: 10),
          if (hasFiat)
            _ContributionOption(
              icon: LucideIcons.creditCard,
              title: 'Fiat Contribution',
              subtitle: _fiatLabel(team.fiatContributionMode),
              color: FzColors.primary,
              onTap: onFiatTap,
            ),
        ],
      ),
    );
  }

  String _fiatLabel(String? mode) {
    switch (mode) {
      case 'revolut_api':
      case 'revolut_link':
        return 'Via Revolut';
      case 'other_payment_link':
        return 'External payment link';
      default:
        return 'Unavailable for this club';
    }
  }
}

class TeamContributionSummaryCard extends StatelessWidget {
  const TeamContributionSummaryCard({super.key, required this.contributions});

  final List<TeamContributionModel> contributions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final totalFet = contributions
        .where((c) => c.contributionType == 'fet' && c.status == 'completed')
        .fold<int>(0, (sum, c) => sum + (c.amountFet ?? 0));

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR CONTRIBUTIONS',
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FzColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.coins,
                  size: 20,
                  color: FzColors.secondary,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalFet FET',
                    style: FzTypography.score(
                      size: 20,
                      color: isDark ? FzColors.darkText : FzColors.lightText,
                    ),
                  ),
                  Text(
                    '${contributions.length} contribution${contributions.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Column(
      children: [
        Icon(icon, size: 18, color: FzColors.primary),
        const SizedBox(height: 8),
        Text(value, style: FzTypography.score(size: 16)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ContributionOption extends StatelessWidget {
  const _ContributionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
