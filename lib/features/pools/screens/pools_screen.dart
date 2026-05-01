import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../data/pools_repository.dart';

export '../data/pools_repository.dart'
    show PoolCamp, PoolSummary, poolsProvider;

class PoolsScreen extends ConsumerStatefulWidget {
  const PoolsScreen({super.key});

  @override
  ConsumerState<PoolsScreen> createState() => _PoolsScreenState();
}

class _PoolsScreenState extends ConsumerState<PoolsScreen> {
  static const _filters = [
    _PoolFilter(label: 'Featured', scope: null),
    _PoolFilter(label: 'Global', scope: 'global'),
    _PoolFilter(label: 'My Country', scope: 'country'),
    _PoolFilter(label: 'This Bar', scope: 'venue'),
    _PoolFilter(label: 'My Pools', scope: 'mine'),
  ];

  var _selectedFilter = 0;

  Future<void> _openStake(
    BuildContext context,
    PoolSummary pool,
    PoolCamp? camp,
  ) async {
    final isVerified = ref.read(isFullyAuthenticatedProvider);
    if (!isVerified) {
      await showSignInRequiredSheet(
        context,
        title: 'Verify WhatsApp to join pools',
        message:
            'Verify your WhatsApp number before staking FET into a match pool.',
        from: '/pools',
      );
      return;
    }

    final campQuery = camp == null
        ? ''
        : '?camp=${Uri.encodeComponent(camp.id)}';
    await context.push('/pool/${pool.id}/join$campQuery');
  }

  @override
  Widget build(BuildContext context) {
    final poolsAsync = ref.watch(poolsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(poolsProvider.future),
          child: poolsAsync.when(
            data: (pools) {
              final filtered = _applyFilter(pools, _filters[_selectedFilter]);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pools',
                          style: FzTypography.display(
                            size: 38,
                            color: textColor,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Create pool',
                        onPressed: () => context.push('/pools/create'),
                        style: IconButton.styleFrom(
                          backgroundColor: FzColors.accent2,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PoolsHero(
                    pools: pools,
                    onJoinPool: () => setState(() => _selectedFilter = 0),
                    onCreatePool: () => context.push('/pools/create'),
                  ),
                  const SizedBox(height: 16),
                  _PoolFilterBar(
                    filters: _filters,
                    selectedIndex: _selectedFilter,
                    onChanged: (index) =>
                        setState(() => _selectedFilter = index),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    FzEmptyState(
                      title: _emptyTitle(_filters[_selectedFilter]),
                      description: _emptyDescription(_filters[_selectedFilter]),
                      icon: const Icon(LucideIcons.trophy),
                      actionLabel: _selectedFilter == 0
                          ? 'Create a pool'
                          : 'Show featured',
                      onAction: _selectedFilter == 0
                          ? () => context.push('/pools/create')
                          : () => setState(() => _selectedFilter = 0),
                    )
                  else
                    ...filtered.map(
                      (pool) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PoolCard(
                          pool: pool,
                          onOpen: () => context.push('/pool/'),
                          onStake: (camp) => _openStake(context, pool, camp),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 140),
              children: [
                StateView.error(
                  title: 'Pools unavailable',
                  subtitle: error.toString(),
                  onRetry: () => ref.invalidate(poolsProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<PoolSummary> _applyFilter(
    List<PoolSummary> pools,
    _PoolFilter filter,
  ) {
    if (filter.scope == null) {
      return pools
          .where((pool) => pool.isOfficial || pool.status == 'open')
          .toList(growable: false);
    }
    if (filter.scope == 'mine') {
      return pools
          .where((pool) => pool.status == 'open' || pool.status == 'locked')
          .toList(growable: false);
    }
    return pools
        .where((pool) => pool.scope == filter.scope)
        .toList(growable: false);
  }

  static String _emptyTitle(_PoolFilter filter) {
    switch (filter.scope) {
      case 'global':
        return 'No global pools';
      case 'country':
        return 'No country pools';
      case 'venue':
        return 'No bar pools';
      case 'mine':
        return 'No active entries';
      default:
        return 'No featured pools';
    }
  }

  static String _emptyDescription(_PoolFilter filter) {
    switch (filter.scope) {
      case 'mine':
        return 'Join a pool to track your stake, live stats, and settlement result here.';
      case 'venue':
        return 'This bar will show its match pools as soon as they open.';
      default:
        return 'Open pools appear here when featured matches are ready for stakes.';
    }
  }
}

class _PoolFilter {
  const _PoolFilter({required this.label, required this.scope});

  final String label;
  final String? scope;
}

class _PoolsHero extends StatelessWidget {
  const _PoolsHero({
    required this.pools,
    required this.onJoinPool,
    required this.onCreatePool,
  });

  final List<PoolSummary> pools;
  final VoidCallback onJoinPool;
  final VoidCallback onCreatePool;

  @override
  Widget build(BuildContext context) {
    final open = pools.where((pool) => pool.status == 'open').length;
    final totalStaked = pools.fold<int>(
      0,
      (sum, pool) => sum + pool.totalStakedFet,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.teal, FzColors.accent2],
          stops: [0, 0.54, 1],
        ),
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: FzColors.accent2.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATCH STAKES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$open open pools',
            style: FzTypography.display(
              size: 32,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalStaked FET staked across featured matches',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: 'Join Pool',
                  icon: LucideIcons.trophy,
                  background: Colors.white,
                  foreground: FzColors.darkBg,
                  onTap: onJoinPool,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroButton(
                  label: 'Create',
                  icon: LucideIcons.plus,
                  background: Colors.white.withValues(alpha: 0.12),
                  foreground: Colors.white,
                  onTap: onCreatePool,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: FzRadii.compactRadius,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: background,
          borderRadius: FzRadii.compactRadius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolFilterBar extends StatelessWidget {
  const _PoolFilterBar({
    required this.filters,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<_PoolFilter> filters;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            selected: selected,
            label: Text(filters[index].label),
            onSelected: (_) => onChanged(index),
            selectedColor: FzColors.accent.withValues(alpha: 0.18),
            backgroundColor: FzColors.darkSurface2,
            labelStyle: TextStyle(
              color: selected ? FzColors.accent : FzColors.darkMuted,
              fontWeight: FontWeight.w900,
            ),
            side: BorderSide(
              color: selected ? FzColors.accent : FzColors.darkBorder,
            ),
          );
        },
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({
    required this.pool,
    required this.onOpen,
    required this.onStake,
  });

  final PoolSummary pool;
  final VoidCallback onOpen;
  final ValueChanged<PoolCamp?> onStake;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pool.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(status: pool.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PoolTag(label: '${pool.scope} pool', icon: LucideIcons.globe2),
              if (pool.countryCode != null)
                _PoolTag(label: pool.countryCode!, icon: LucideIcons.flag),
              if (pool.isOfficial)
                const _PoolTag(label: 'official', icon: LucideIcons.badgeCheck),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: 'Members', value: '${pool.totalMembers}'),
              const SizedBox(width: 10),
              _Metric(label: 'Pooled', value: '${pool.totalStakedFet} FET'),
              const SizedBox(width: 10),
              _Metric(label: 'Stake', value: '${pool.defaultStakeFet} FET'),
            ],
          ),
          const SizedBox(height: 14),
          if (pool.camps.isEmpty)
            const Text(
              'Pool camps are not published yet.',
              style: TextStyle(fontSize: 13, color: FzColors.darkMuted),
            )
          else
            ...pool.camps
                .take(3)
                .map(
                  (camp) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CampStakeButton(
                      camp: camp,
                      enabled: pool.isOpen,
                      onTap: () => onStake(camp),
                    ),
                  ),
                ),
          if (pool.camps.length > 3)
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(LucideIcons.chevronRight, size: 16),
              label: const Text('View all camps'),
            ),
          if (pool.isSettled) ...[
            const SizedBox(height: 4),
            const _SettlementResultHint(),
          ],
        ],
      ),
    );
  }
}

class _CampStakeButton extends StatelessWidget {
  const _CampStakeButton({
    required this.camp,
    required this.enabled,
    required this.onTap,
  });

  final PoolCamp camp;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: const RoundedRectangleBorder(borderRadius: FzRadii.buttonRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              camp.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${camp.memberCount} - ${camp.totalStakedFet} FET',
            style: const TextStyle(fontSize: 12, color: FzColors.darkMuted),
          ),
        ],
      ),
    );
  }
}

class _PoolTag extends StatelessWidget {
  const _PoolTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: FzColors.accent),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: FzColors.darkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementResultHint extends StatelessWidget {
  const _SettlementResultHint();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(LucideIcons.badgeCheck, size: 16, color: FzColors.success),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Settlement results are final for this pool.',
            style: TextStyle(fontSize: 12, color: FzColors.darkMuted),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: FzColors.primary.withValues(alpha: 0.06),
          borderRadius: FzRadii.buttonRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: FzColors.darkMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'open'
        ? FzColors.success
        : status == 'settled'
        ? FzColors.accent2
        : FzColors.darkMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
