import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/match_model.dart';
import '../../../models/pool.dart';
import '../../../models/team_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/pool_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/team_crest.dart';

class LeagueHubScreen extends ConsumerWidget {
  const LeagueHubScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(competitionProvider(leagueId));
    final matchesAsync = ref.watch(competitionMatchesProvider(leagueId));
    final poolsAsync = ref.watch(poolServiceProvider);
    final teamsAsync = ref.watch(teamsByCompetitionProvider(leagueId));

    return competitionAsync.when(
      data: (competition) {
        if (competition == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Competition')),
            body: StateView.empty(
              title: 'Competition not found',
              subtitle: 'Return to fixtures.',
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
        final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
        final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
        final textColor = isDark ? FzColors.darkText : FzColors.lightText;

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: surface.withValues(alpha: 0.92),
                    border: Border(bottom: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/fixtures'),
                        icon: Icon(
                          LucideIcons.chevronLeft,
                          size: 24,
                          color: textColor,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _leagueEyebrow(competition).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: muted,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              competition.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _LeagueHero(
                    emoji: _leagueEmoji(competition.id),
                    name: competition.name,
                    liveCount:
                        matchesAsync.valueOrNull
                            ?.where((match) => match.isLive)
                            .length ??
                        0,
                    activePoolCount: _leaguePools(
                      poolsAsync.valueOrNull ?? const <ScorePool>[],
                      matchesAsync.valueOrNull ?? const <MatchModel>[],
                    ).length,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionHeader(
                    title: 'Action Center',
                    actionLabel: 'SEE ALL',
                    badge: const FzBadge(
                      label: 'LIVE',
                      variant: FzBadgeVariant.danger,
                      pulse: true,
                    ),
                    onTap: () => context.go('/fixtures'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: matchesAsync.when(
                    data: (matches) {
                      final spotlight = _spotlightMatches(matches);
                      if (spotlight.isEmpty) {
                        return StateView.empty(
                          title: 'No league fixtures right now',
                          subtitle: 'Upcoming matches will appear here.',
                          icon: LucideIcons.activity,
                        );
                      }

                      return Column(
                        children: [
                          for (int index = 0; index < spotlight.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == spotlight.length - 1 ? 0 : 12,
                              ),
                              child: _LeagueMatchCard(match: spotlight[index]),
                            ),
                        ],
                      );
                    },
                    loading: () => const _LeagueSectionSkeleton(),
                    error: (_, _) => StateView.error(
                      title: 'Could not load league fixtures',
                      onRetry: () =>
                          ref.invalidate(competitionMatchesProvider(leagueId)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionHeader(
                    title: 'Hot Pools',
                    icon: LucideIcons.swords,
                    actionLabel: 'BROWSE POOLS',
                    onTap: () => context.go('/pools'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: poolsAsync.when(
                    data: (pools) {
                      final leaguePools = _leaguePools(
                        pools,
                        matchesAsync.valueOrNull ?? const <MatchModel>[],
                      ).take(2).toList(growable: false);
                      if (leaguePools.isEmpty) {
                        return StateView.empty(
                          title: 'No league pools yet',
                          subtitle:
                              'Open pools for this competition will show here.',
                          icon: LucideIcons.swords,
                        );
                      }

                      return Column(
                        children: [
                          for (
                            int index = 0;
                            index < leaguePools.length;
                            index++
                          )
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == leaguePools.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: _LeaguePoolCard(pool: leaguePools[index]),
                            ),
                        ],
                      );
                    },
                    loading: () => const _LeagueSectionSkeleton(),
                    error: (_, _) => StateView.error(
                      title: 'Could not load league pools',
                      onRetry: () => ref.invalidate(poolServiceProvider),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionHeader(title: 'Top Registries'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: teamsAsync.when(
                    data: (teams) {
                      final topTeams = [...teams]
                        ..sort((a, b) => b.fanCount.compareTo(a.fanCount));
                      final visible = topTeams.take(2).toList(growable: false);
                      if (visible.isEmpty) {
                        return StateView.empty(
                          title: 'No registries available',
                          subtitle: 'Club communities will appear here.',
                          icon: LucideIcons.shield,
                        );
                      }

                      return FzCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (
                              int index = 0;
                              index < visible.length;
                              index++
                            ) ...[
                              _RegistryRow(team: visible[index]),
                              if (index < visible.length - 1)
                                Divider(height: 1, color: border, indent: 68),
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const _LeagueSectionSkeleton(),
                    error: (_, _) => StateView.error(
                      title: 'Could not load registries',
                      onRetry: () =>
                          ref.invalidate(teamsByCompetitionProvider(leagueId)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: ScoresPageSkeleton()),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Competition')),
        body: StateView.error(
          title: 'Competition unavailable',
          subtitle: 'Try again later.',
          onRetry: () => ref.invalidate(competitionProvider(leagueId)),
        ),
      ),
    );
  }

  List<MatchModel> _spotlightMatches(List<MatchModel> matches) {
    final live = matches.where((match) => match.isLive).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final upcoming = matches.where((match) => match.isUpcoming).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return [...live, ...upcoming].take(2).toList(growable: false);
  }

  List<ScorePool> _leaguePools(
    List<ScorePool> pools,
    List<MatchModel> matches,
  ) {
    final ids = matches.map((match) => match.id).toSet();
    return pools
        .where((pool) => pool.status == 'open' && ids.contains(pool.matchId))
        .toList()
      ..sort((a, b) => b.totalPool.compareTo(a.totalPool));
  }
}

String _leagueEyebrow(dynamic competition) {
  final id = competition.id.toString().toLowerCase();
  final country = competition.country.toString().toLowerCase();
  if (id.contains('ucl') ||
      id.contains('europa') ||
      id.contains('champions') ||
      id.contains('conference') ||
      country.contains('europe')) {
    return 'Europe';
  }
  return 'League Action';
}

String _leagueEmoji(String id) {
  final normalized = id.toLowerCase();
  if (normalized.contains('ucl') || normalized.contains('champions')) {
    return '⭐';
  }
  if (normalized.contains('world')) {
    return '🌎';
  }
  return '🏆';
}

class _LeagueHero extends StatelessWidget {
  const _LeagueHero({
    required this.emoji,
    required this.name,
    required this.liveCount,
    required this.activePoolCount,
  });

  final String emoji;
  final String name;
  final int liveCount;
  final int activePoolCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -10,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FzColors.primary.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? FzColors.darkSurface
                            : FzColors.lightSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: border),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 30)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: FzTypography.display(
                              size: 30,
                              color: textColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _HeroMeta(
                                icon: LucideIcons.zap,
                                label: liveCount > 0 ? 'Live Now' : 'Fixtures',
                                color: FzColors.primary,
                                muted: muted,
                              ),
                              _HeroMeta(
                                icon: LucideIcons.users,
                                label: '$activePoolCount Active Pools',
                                color: muted,
                                muted: muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push('/pools/create'),
                        style: FilledButton.styleFrom(
                          backgroundColor: FzColors.primary,
                          foregroundColor: FzColors.darkBg,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text(
                          'NEW POOL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/memberships'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: border),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(LucideIcons.shield, size: 16),
                        label: const Text(
                          'CLUBS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({
    required this.icon,
    required this.label,
    required this.color,
    required this.muted,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.icon,
    this.actionLabel,
    this.onTap,
    this.badge,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                badge!,
              ] else if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: FzColors.coral),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onTap,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FzColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _LeagueMatchCard extends StatelessWidget {
  const _LeagueMatchCard({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      onTap: () => context.push('/match/${match.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (match.isLive)
            const FzBadge(
              label: 'LIVE',
              variant: FzBadgeVariant.danger,
              pulse: true,
            ),
          if (match.isLive) const SizedBox(height: 12),
          _TeamLine(
            name: match.homeTeam,
            crestUrl: match.homeLogoUrl,
            trailing: match.isLive ? '${match.ftHome ?? 0}' : null,
          ),
          const SizedBox(height: 10),
          _TeamLine(
            name: match.awayTeam,
            crestUrl: match.awayLogoUrl,
            trailing: match.isLive ? '${match.ftAway ?? 0}' : null,
          ),
          const SizedBox(height: 16),
          Text(
            match.isLive ? match.liveStatusLabel() : match.kickoffLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: match.isLive ? FzColors.primary : muted,
              letterSpacing: 1,
            ),
          ),
          if (!match.isLive) ...[
            const SizedBox(height: 4),
            Text(
              match.round?.toUpperCase() ?? 'UPCOMING',
              style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.74),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.name, required this.crestUrl, this.trailing});

  final String name;
  final String? crestUrl;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;
    return Row(
      children: [
        TeamCrest(
          label: name,
          crestUrl: crestUrl,
          size: 28,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? FzColors.darkSurface3
              : FzColors.lightSurface3,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
      ],
    );
  }
}

class _LeaguePoolCard extends StatelessWidget {
  const _LeaguePoolCard({required this.pool});

  final ScorePool pool;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FzBadge(
                        label: 'Stake: ${pool.stake} FET',
                        variant: FzBadgeVariant.ghost,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pool.matchName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'By ${pool.creatorName} • ${pool.participantsCount} entries',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL POOL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pool.totalPool} FET',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: FzColors.coral,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/pool/${pool.id}'),
                    child: const Text('VIEW POOL'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: () => context.push('/pool/${pool.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FzColors.coral,
                      foregroundColor: FzColors.darkBg,
                    ),
                    child: const Text('JOIN'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistryRow extends StatelessWidget {
  const _RegistryRow({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return InkWell(
      onTap: () => context.push('/team/${team.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TeamCrest(
              label: team.name,
              crestUrl: team.crestUrl ?? team.logoUrl,
              size: 40,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${team.fanCount} Members',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

class _LeagueSectionSkeleton extends StatelessWidget {
  const _LeagueSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        FzShimmer(width: double.infinity, height: 132),
        SizedBox(height: 12),
        FzShimmer(width: double.infinity, height: 132),
      ],
    );
  }
}
