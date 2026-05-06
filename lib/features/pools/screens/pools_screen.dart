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
import '../../../widgets/common/fz_reference_chrome.dart';
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
  var _filter = _ArenaFilter.live;

  Future<void> _joinPool(PoolSummary pool, [PoolCamp? camp]) async {
    final isVerified = ref.read(isFullyAuthenticatedProvider);
    if (!isVerified) {
      await showSignInRequiredSheet(
        context,
        title: 'Verify WhatsApp',
        message: 'Unlock pools.',
        from: '/pools',
      );
      return;
    }

    final campQuery = camp == null
        ? ''
        : '?camp=${Uri.encodeComponent(camp.id)}';
    if (mounted) {
      await context.push('/pool/${pool.id}/join$campQuery');
    }
  }

  @override
  Widget build(BuildContext context) {
    final poolsAsync = ref.watch(poolsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'create-pool',
        tooltip: 'Create pool',
        onPressed: () => context.push('/pools/create'),
        backgroundColor: FzColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(poolsProvider);
            await ref.read(poolsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
            children: [
              const FzReferenceHeader(title: 'FZ'),
              const SizedBox(height: 24),
              Text(
                'PLAY',
                style: FzTypography.sportsTitle(
                  size: 42,
                  color: FzColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pools. Games. FET.',
                style: TextStyle(
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.trophy, size: 16),
                      label: const Text('Pools'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/games'),
                      icon: const Icon(LucideIcons.gamepad2, size: 16),
                      label: const Text('Games'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'Live',
                      filter: _ArenaFilter.live,
                      selected: _filter == _ArenaFilter.live,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Soon',
                      filter: _ArenaFilter.soon,
                      selected: _filter == _ArenaFilter.soon,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Big Pot',
                      filter: _ArenaFilter.bigPool,
                      selected: _filter == _ArenaFilter.bigPool,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Entries',
                      filter: _ArenaFilter.entries,
                      selected: _filter == _ArenaFilter.entries,
                      onTap: _setFilter,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              poolsAsync.when(
                data: (pools) {
                  final visible = _applyFilter(pools);
                  if (visible.isEmpty) {
                    return FzEmptyState(
                      title: _emptyTitle,
                      description: _emptyDescription,
                      icon: const Icon(LucideIcons.trophy),
                      actionLabel: _filter == _ArenaFilter.entries
                          ? 'Pools'
                          : 'Create',
                      onAction: _filter == _ArenaFilter.entries
                          ? () => _setFilter(_ArenaFilter.live)
                          : () => context.push('/pools/create'),
                    );
                  }
                  return Column(
                    children: [
                      for (final pool in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ArenaPoolCard(
                            pool: pool,
                            onOpen: () => context.push('/pool/${pool.id}'),
                            onJoin: (camp) => _joinPool(pool, camp),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => StateView.error(
                  title: 'Arena unavailable',
                  subtitle: error.toString(),
                  onRetry: () => ref.invalidate(poolsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setFilter(_ArenaFilter filter) => setState(() => _filter = filter);

  List<PoolSummary> _applyFilter(List<PoolSummary> pools) {
    switch (_filter) {
      case _ArenaFilter.live:
        return pools
            .where((pool) => const {'open', 'live'}.contains(pool.status))
            .toList(growable: false);
      case _ArenaFilter.soon:
        return pools
            .where((pool) => const {'locked', 'settling'}.contains(pool.status))
            .toList(growable: false);
      case _ArenaFilter.bigPool:
        final sorted = [...pools]
          ..sort((a, b) => b.totalStakedFet.compareTo(a.totalStakedFet));
        return sorted.take(20).toList(growable: false);
      case _ArenaFilter.entries:
        return pools.where((pool) => pool.hasMyEntry).toList(growable: false);
    }
  }

  String get _emptyTitle {
    switch (_filter) {
      case _ArenaFilter.entries:
        return 'No entries';
      case _ArenaFilter.soon:
        return 'No rooms';
      default:
        return 'No pools';
    }
  }

  String get _emptyDescription {
    switch (_filter) {
      case _ArenaFilter.entries:
        return 'Join one.';
      case _ArenaFilter.soon:
        return 'Check soon.';
      default:
        return 'Create one.';
    }
  }
}

enum _ArenaFilter { live, soon, bigPool, entries }

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _ArenaFilter filter;
  final bool selected;
  final ValueChanged<_ArenaFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FzPill(
        label: label,
        selected: selected,
        onTap: () => onTap(filter),
      ),
    );
  }
}

class _ArenaPoolCard extends StatelessWidget {
  const _ArenaPoolCard({
    required this.pool,
    required this.onOpen,
    required this.onJoin,
  });

  final PoolSummary pool;
  final VoidCallback onOpen;
  final ValueChanged<PoolCamp?> onJoin;

  @override
  Widget build(BuildContext context) {
    final primaryCamp = pool.camps.isEmpty ? null : pool.camps.first;
    final secondaryCamp = pool.camps.length < 2 ? null : pool.camps[1];

    return FzCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(18),
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FzPill(
                label: pool.status.toUpperCase(),
                icon: pool.isOpen ? LucideIcons.zap : LucideIcons.clock,
                color: pool.isOpen ? FzColors.green : FzColors.gold,
                selected: true,
              ),
              const Spacer(),
              const Text(
                'BAR',
                style: TextStyle(
                  color: FzColors.darkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _CampOrb(label: primaryCamp?.label ?? 'HOME'),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      pool.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: FzTypography.display(
                        size: 23,
                        color: FzColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pool.venueName == null ? 'Bar needed' : pool.venueName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FzColors.darkMuted,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _CampOrb(label: secondaryCamp?.label ?? 'AWAY'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FzMetricTile(
                  label: 'Stake',
                  value: '${pool.defaultStakeFet} FET',
                  color: FzColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FzMetricTile(
                  label: 'Pot',
                  value: '${pool.totalStakedFet}',
                  color: FzColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FzMetricTile(
                  label: 'Entries',
                  value: '${pool.totalMembers}',
                  color: FzColors.gold,
                ),
              ),
            ],
          ),
          if (pool.camps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final camp in pool.camps.take(3))
                  FzPill(
                    label: camp.label,
                    icon: LucideIcons.users,
                    onTap: pool.isOpen ? () => onJoin(camp) : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(LucideIcons.eye, size: 16),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: pool.isOpen ? () => onJoin(primaryCamp) : null,
                  icon: const Icon(LucideIcons.trophy, size: 16),
                  label: const Text('Join'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampOrb extends StatelessWidget {
  const _CampOrb({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        shape: BoxShape.circle,
        border: Border.all(color: FzColors.darkBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'FC' : initials,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }
}
