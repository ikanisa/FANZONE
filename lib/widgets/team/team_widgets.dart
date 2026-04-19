import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/team_model.dart';
import '../../models/team_contribution_model.dart';
import '../../models/team_news_model.dart';
import '../../services/team_community_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../common/fz_card.dart';
import '../common/fz_animated_entry.dart';
import '../match/match_list_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// TeamCard — discovery grid / list item
// ═══════════════════════════════════════════════════════════════

class TeamCard extends ConsumerWidget {
  const TeamCard({
    super.key,
    required this.team,
    this.onTap,
    this.index = 0,
  });

  final TeamModel team;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final supported = ref.watch(supportedTeamsServiceProvider).valueOrNull ?? {};
    final isSupported = supported.contains(team.id);

    return FzAnimatedEntry(
      index: index,
      child: FzCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TeamAvatar(name: team.name, logoUrl: team.logoUrl ?? team.crestUrl, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (team.leagueName != null || team.country != null)
                        Expanded(
                          child: Text(
                            team.leagueName ?? team.country ?? '',
                            style: TextStyle(fontSize: 12, color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (team.fanCount > 0) ...[
                        const SizedBox(width: 8),
                        SupporterCounterChip(count: team.fanCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SupportTeamButton(
              isSupported: isSupported,
              compact: true,
              onTap: () => ref
                  .read(supportedTeamsServiceProvider.notifier)
                  .toggleSupport(team.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SupportedTeamCard — compact card in "My Teams"
// ═══════════════════════════════════════════════════════════════

class SupportedTeamCard extends StatelessWidget {
  const SupportedTeamCard({
    super.key,
    required this.team,
    this.onTap,
    this.onUnsupport,
    this.index = 0,
  });

  final TeamModel team;
  final VoidCallback? onTap;
  final VoidCallback? onUnsupport;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzAnimatedEntry(
      index: index,
      child: FzCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            TeamAvatar(name: team.name, logoUrl: team.logoUrl ?? team.crestUrl, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (team.fanCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${_formatCount(team.fanCount)} supporters',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TeamHeroHeader — premium hero for team profile page
// ═══════════════════════════════════════════════════════════════

class TeamHeroHeader extends ConsumerWidget {
  const TeamHeroHeader({super.key, required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final supported = ref.watch(supportedTeamsServiceProvider).valueOrNull ?? {};
    final isSupported = supported.contains(team.id);

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Gradient hero area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FzColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                  FzColors.violet.withValues(alpha: isDark ? 0.1 : 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                TeamAvatar(
                  name: team.name,
                  logoUrl: team.logoUrl ?? team.crestUrl,
                  size: 72,
                ),
                const SizedBox(height: 14),
                Text(
                  team.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                if (team.leagueName != null || team.country != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [team.leagueName, team.country]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(fontSize: 13, color: muted),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (team.description != null && team.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    team.description!,
                    style: TextStyle(fontSize: 13, color: muted, height: 1.5),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Stats + action row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                _HeroStat(label: 'Fans', value: _formatCount(team.fanCount)),
                const SizedBox(width: 16),
                _HeroStat(label: 'Leagues', value: '${team.competitionIds.length}'),
                const Spacer(),
                SupportTeamButton(
                  isSupported: isSupported,
                  compact: false,
                  onTap: () => ref
                      .read(supportedTeamsServiceProvider.notifier)
                      .toggleSupport(team.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Column(
      children: [
        Text(value, style: FzTypography.score(size: 18)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SupportTeamButton — toggle follow/support CTA
// ═══════════════════════════════════════════════════════════════

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
            isSupported ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(isSupported),
            size: 22,
            color: isSupported ? FzColors.maltaRed : FzColors.darkMuted,
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
              ? FzColors.maltaRed.withValues(alpha: 0.15)
              : FzColors.accent,
          foregroundColor: isSupported ? FzColors.maltaRed : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(
          isSupported ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 18,
        ),
        label: Text(
          isSupported ? 'Supporting' : 'Support',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SupporterCounterChip — compact fan count display
// ═══════════════════════════════════════════════════════════════

class SupporterCounterChip extends StatelessWidget {
  const SupporterCounterChip({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FzColors.accent.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 12, color: FzColors.accent),
          const SizedBox(width: 4),
          Text(
            _formatCount(count),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FzColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AnonymousFanBadge — shows FAN-XXXX
// ═══════════════════════════════════════════════════════════════

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
                color: FzColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(LucideIcons.user, size: 16, color: FzColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fanId,
                    style: FzTypography.scoreCompact(),
                  ),
                  if (joinedAt != null)
                    Text(
                      'Joined ${_timeAgo(joinedAt!)}',
                      style: TextStyle(fontSize: 11, color: muted),
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

// ═══════════════════════════════════════════════════════════════
// CommunityStatsCard — fan count, growth, contributions
// ═══════════════════════════════════════════════════════════════

class CommunityStatsCard extends StatelessWidget {
  const CommunityStatsCard({super.key, required this.stats});
  final TeamCommunityStats stats;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _StatTile(label: 'Total Fans', value: _formatCount(stats.fanCount), icon: LucideIcons.users)),
          Expanded(child: _StatTile(label: 'New (30d)', value: _formatCount(stats.supportersLast30d), icon: LucideIcons.trendingUp)),
          Expanded(child: _StatTile(label: 'FET Pool', value: _formatCount(stats.totalFetContributed), icon: LucideIcons.coins)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Column(
      children: [
        Icon(icon, size: 18, color: FzColors.accent),
        const SizedBox(height: 8),
        Text(value, style: FzTypography.score(size: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ContributionCTA — FET / fiat donation call-to-action
// ═══════════════════════════════════════════════════════════════

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
              color: FzColors.amber,
              onTap: onFetTap,
            ),
          if (hasFet && hasFiat) const SizedBox(height: 10),
          if (hasFiat)
            _ContributionOption(
              icon: LucideIcons.creditCard,
              title: 'Fiat Contribution',
              subtitle: _fiatLabel(team.fiatContributionMode),
              color: FzColors.accent,
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
        return 'Coming soon';
    }
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
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
            Icon(Icons.chevron_right_rounded, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TeamNewsCard — curated news card
// ═══════════════════════════════════════════════════════════════

class TeamNewsCard extends StatelessWidget {
  const TeamNewsCard({
    super.key,
    required this.news,
    this.onTap,
    this.index = 0,
  });

  final TeamNewsModel news;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzAnimatedEntry(
      index: index,
      child: FzCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category + source row
            Row(
              children: [
                TeamNewsCategoryChip(category: news.category),
                const Spacer(),
                if (news.isAiCurated)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.sparkles, size: 12, color: FzColors.violet),
                      SizedBox(width: 4),
                      Text(
                        'AI Curated',
                        style: TextStyle(fontSize: 10, color: FzColors.violet, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              news.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (news.summary != null) ...[
              const SizedBox(height: 6),
              Text(
                news.summary!,
                style: TextStyle(fontSize: 13, color: muted, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            // Footer
            Row(
              children: [
                if (news.sourceName != null)
                  Text(
                    news.sourceName!,
                    style: const TextStyle(fontSize: 11, color: FzColors.accent, fontWeight: FontWeight.w500),
                  ),
                const Spacer(),
                if (news.publishedAt != null)
                  Text(
                    _timeAgo(news.publishedAt!),
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TeamNewsCategoryChip
// ═══════════════════════════════════════════════════════════════

class TeamNewsCategoryChip extends StatelessWidget {
  const TeamNewsCategoryChip({super.key, required this.category, this.onTap, this.selected = false});
  final String category;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? FzColors.accent.withValues(alpha: 0.15)
              : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? FzColors.accent : Colors.transparent,
          ),
        ),
        child: Text(
          TeamNewsCategory.label(category),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? FzColors.accent : (isDark ? FzColors.darkMuted : FzColors.lightMuted),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TeamContributionSummaryCard
// ═══════════════════════════════════════════════════════════════

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
          Text('YOUR CONTRIBUTIONS', style: FzTypography.sectionLabel(Theme.of(context).brightness)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FzColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.coins, size: 20, color: FzColors.amber),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalFet FET',
                    style: FzTypography.score(size: 20, color: isDark ? FzColors.darkText : FzColors.lightText),
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

// ═══════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${date.day}/${date.month}/${date.year}';
}
