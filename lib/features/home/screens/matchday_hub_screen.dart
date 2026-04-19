import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/match_model.dart';
import '../../../models/pool.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/pool_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

class MatchdayHubScreen extends ConsumerWidget {
  const MatchdayHubScreen({super.key});

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesByDateProvider(_today));
    final poolsAsync = ref.watch(poolServiceProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: FzColors.accent,
        onRefresh: () async {
          ref.invalidate(matchesByDateProvider(_today));
          ref.invalidate(poolServiceProvider);
          await Future.wait([
            ref.read(matchesByDateProvider(_today).future),
            ref.read(poolServiceProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
          children: [
            _HomeHeader(
              onOpenPools: () => context.go('/predict'),
              onOpenRegistry: () => context.go('/clubs/fan-id'),
            ),
            const SizedBox(height: 20),
            _DailyInsightCard(
              matchesAsync: matchesAsync,
              poolsAsync: poolsAsync,
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              icon: LucideIcons.activity,
              iconColor: FzColors.danger,
              title: 'Live Action',
              trailing: matchesAsync.when(
                data: (matches) => _CountBadge(
                  count: matches.where((match) => match.isLive).length,
                  color: FzColors.danger,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            matchesAsync.when(
              data: (matches) {
                final liveMatches =
                    matches.where((match) => match.isLive).toList()
                      ..sort((a, b) => a.date.compareTo(b.date));
                if (liveMatches.isEmpty) {
                  return const _ReferenceEmptyState(
                    title: 'No live matches',
                    subtitle:
                        'Check upcoming fixtures and set your next picks.',
                    icon: LucideIcons.trophy,
                  );
                }
                return MatchListCard(
                  matches: liveMatches.take(4).toList(),
                  onTapMatch: (match) => context.push('/match/${match.id}'),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => StateView.error(
                title: 'Could not load live action',
                onRetry: () => ref.invalidate(matchesByDateProvider(_today)),
              ),
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              icon: LucideIcons.calendar,
              iconColor: FzColors.darkMuted,
              title: 'Upcoming',
              trailing: IconButton(
                onPressed: () => context.go('/fixtures'),
                tooltip: 'Open fixtures',
                icon: const Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: FzColors.darkMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            matchesAsync.when(
              data: (matches) {
                final upcomingMatches =
                    matches.where((match) => match.isUpcoming).toList()
                      ..sort((a, b) => a.date.compareTo(b.date));
                if (upcomingMatches.isEmpty) {
                  return const _ReferenceEmptyState(
                    title: 'No upcoming fixtures',
                    subtitle:
                        'The next football window has not been loaded yet.',
                    icon: LucideIcons.calendar,
                  );
                }
                return MatchListCard(
                  matches: upcomingMatches.take(6).toList(),
                  onTapMatch: (match) => context.push('/match/${match.id}'),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => StateView.error(
                title: 'Could not load upcoming fixtures',
                onRetry: () => ref.invalidate(matchesByDateProvider(_today)),
              ),
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              icon: LucideIcons.swords,
              iconColor: FzColors.accent,
              title: 'Featured Pools',
              trailing: TextButton(
                onPressed: () => context.go('/predict'),
                child: const Text('Open Pools'),
              ),
            ),
            const SizedBox(height: 12),
            poolsAsync.when(
              data: (pools) {
                final openPools =
                    pools.where((pool) => pool.status == 'open').toList()
                      ..sort((a, b) => a.lockAt.compareTo(b.lockAt));
                if (openPools.isEmpty) {
                  return const _ReferenceEmptyState(
                    title: 'No open pools',
                    subtitle:
                        'Use free match predictions now and come back when the next pool window opens.',
                    icon: LucideIcons.swords,
                  );
                }

                return Column(
                  children: [
                    for (
                      var index = 0;
                      index < openPools.take(3).length;
                      index++
                    ) ...[
                      _PoolPreviewCard(
                        pool: openPools[index],
                        onTap: () => context.push(
                          '/predict/pool/${openPools[index].id}',
                        ),
                      ),
                      if (index < openPools.take(3).length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => StateView.error(
                title: 'Could not load pools',
                onRetry: () => ref.invalidate(poolServiceProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onOpenPools, required this.onOpenRegistry});

  final VoidCallback onOpenPools;
  final VoidCallback onOpenRegistry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Predictions',
            style: FzTypography.display(
              size: 40,
              color: FzColors.darkText,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _HeaderIconButton(
          icon: LucideIcons.plusCircle,
          accent: true,
          tooltip: 'Create pool',
          onTap: onOpenPools,
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: LucideIcons.shield,
          tooltip: 'Open Fan ID registry',
          onTap: onOpenRegistry,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent ? FzColors.blue : FzColors.darkSurface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent ? FzColors.blue : FzColors.darkBorder,
            ),
            boxShadow: accent
                ? [
                    BoxShadow(
                      color: FzColors.coral.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: accent ? FzColors.darkBg : FzColors.darkText,
          ),
        ),
      ),
    );
  }
}

class _DailyInsightCard extends StatelessWidget {
  const _DailyInsightCard({
    required this.matchesAsync,
    required this.poolsAsync,
  });

  final AsyncValue<List<MatchModel>> matchesAsync;
  final AsyncValue<List<ScorePool>> poolsAsync;

  @override
  Widget build(BuildContext context) {
    final matches = matchesAsync.valueOrNull ?? const <MatchModel>[];
    final pools = poolsAsync.valueOrNull ?? const <ScorePool>[];
    final liveCount = matches.where((match) => match.isLive).length;
    final openPools = pools.where((pool) => pool.status == 'open').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.darkSurface2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FzColors.success.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: FzColors.success.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FzColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: FzColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 18,
              color: FzColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              liveCount > 0
                  ? '$liveCount matches are live now. Lock your picks first, then use ${openPools > 0 ? '$openPools open pool${openPools == 1 ? '' : 's'}' : 'fan challenges'} when you want extra competition.'
                  : '${openPools > 0 ? '$openPools pool${openPools == 1 ? '' : 's'} are open' : 'The next prediction window is loading'}. Check the upcoming fixtures rail and set your next picks early.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: FzColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing = const SizedBox.shrink(),
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: FzColors.darkText,
          ),
        ),
        const Spacer(),
        trailing,
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ReferenceEmptyState extends StatelessWidget {
  const _ReferenceEmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(icon, size: 22, color: FzColors.darkMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FzColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: FzColors.darkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoolPreviewCard extends StatelessWidget {
  const _PoolPreviewCard({required this.pool, required this.onTap});

  final ScorePool pool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pool.matchName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FzColors.darkText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FzColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pool.stake} FET',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FzColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Created by ${pool.creatorName}. Winner split is based on the settled result after lock.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: FzColors.darkMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PoolMetric(
                label: 'Pool',
                value: '${pool.totalPool} FET',
                accent: FzColors.accent,
              ),
              const SizedBox(width: 10),
              _PoolMetric(
                label: 'Entries',
                value: '${pool.participantsCount}',
                accent: FzColors.coral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoolMetric extends StatelessWidget {
  const _PoolMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FzColors.darkSurface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FzColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FzColors.darkMuted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
