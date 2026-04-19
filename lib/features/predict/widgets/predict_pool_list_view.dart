part of '../screens/predict_screen.dart';

class _PoolListView extends ConsumerStatefulWidget {
  const _PoolListView({
    required this.poolsAsync,
    required this.entriesAsync,
    required this.filter,
  });

  final AsyncValue<List<ScorePool>> poolsAsync;
  final AsyncValue<List<PoolEntry>> entriesAsync;
  final String filter;

  @override
  ConsumerState<_PoolListView> createState() => _PoolListViewState();
}

class _PoolListViewState extends ConsumerState<_PoolListView> {
  String _sortBy = 'newest';
  String _mineFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return widget.poolsAsync.when(
      data: (pools) {
        final userId = ref.watch(currentUserProvider)?.id;
        final joinedPoolIds =
            widget.entriesAsync.valueOrNull
                ?.map((entry) => entry.poolId)
                .toSet() ??
            const <String>{};
        final openPools = pools.where((pool) => pool.status == 'open').toList()
          ..sort((left, right) => left.lockAt.compareTo(right.lockAt));

        List<ScorePool> filtered;
        String emptyTitle;
        String emptySubtitle;

        switch (widget.filter) {
          case 'featured':
            filtered =
                ([...openPools]..sort((left, right) {
                      final byPool = right.totalPool.compareTo(left.totalPool);
                      if (byPool != 0) return byPool;
                      final byParticipants = right.participantsCount.compareTo(
                        left.participantsCount,
                      );
                      if (byParticipants != 0) return byParticipants;
                      return left.lockAt.compareTo(right.lockAt);
                    }))
                    .take(6)
                    .toList();
            emptyTitle = 'No featured pools';
            emptySubtitle = 'Open pools will appear here.';
            break;
          case 'mine':
            filtered =
                userId == null
                      ? <ScorePool>[]
                      : pools
                            .where(
                              (pool) =>
                                  pool.creatorId == userId ||
                                  joinedPoolIds.contains(pool.id),
                            )
                            .toList()
                  ..sort((left, right) => left.lockAt.compareTo(right.lockAt));
            if (_mineFilter == 'active') {
              filtered = filtered
                  .where((pool) => pool.status == 'open')
                  .toList();
            }
            emptyTitle = 'No personal pools';
            emptySubtitle = 'Pools you create or join will appear here.';
            break;
          case 'settled':
            filtered = pools.where((pool) => pool.status == 'settled').toList()
              ..sort((left, right) => right.lockAt.compareTo(left.lockAt));
            emptyTitle = 'No settled pools';
            emptySubtitle = 'Settled results will appear after matches finish.';
            break;
          default:
            filtered = openPools;
            _applySortFilter(filtered);
            emptyTitle = 'No open pools';
            emptySubtitle = 'Create a pool or wait for one to open.';
        }

        final showSortChips = widget.filter == 'open';
        final showMineChips = widget.filter == 'mine';

        return Column(
          children: [
            if (showSortChips)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _SortChip(
                      label: 'Newest',
                      selected: _sortBy == 'newest',
                      onTap: () => setState(() => _sortBy = 'newest'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Highest Pool',
                      selected: _sortBy == 'pool',
                      onTap: () => setState(() => _sortBy = 'pool'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Most Players',
                      selected: _sortBy == 'participants',
                      onTap: () => setState(() => _sortBy = 'participants'),
                      isDark: isDark,
                      muted: muted,
                    ),
                  ],
                ),
              ),
            if (showMineChips)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _SortChip(
                      label: 'All',
                      selected: _mineFilter == 'all',
                      onTap: () => setState(() => _mineFilter = 'all'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Active',
                      selected: _mineFilter == 'active',
                      onTap: () => setState(() => _mineFilter = 'active'),
                      isDark: isDark,
                      muted: muted,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? StateView.empty(
                      title: emptyTitle,
                      subtitle: emptySubtitle,
                      icon: Icons.sports_martial_arts,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _PoolCard(pool: filtered[index]),
                    ),
            ),
          ],
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            const FzShimmer(width: double.infinity, height: 150),
      ),
      error: (error, stackTrace) => StateView.error(
        title: 'Failed to load pools',
        onRetry: () => ref.invalidate(poolServiceProvider),
      ),
    );
  }

  void _applySortFilter(List<ScorePool> list) {
    switch (_sortBy) {
      case 'pool':
        list.sort((a, b) => b.totalPool.compareTo(a.totalPool));
        break;
      case 'participants':
        list.sort((a, b) => b.participantsCount.compareTo(a.participantsCount));
        break;
      default:
        list.sort((a, b) => b.lockAt.compareTo(a.lockAt));
    }
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    required this.muted,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? FzColors.accent.withValues(alpha: 0.15)
              : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? FzColors.accent.withValues(alpha: 0.4)
                : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? FzColors.accent : muted,
          ),
        ),
      ),
    );
  }
}

class _PoolCard extends ConsumerWidget {
  const _PoolCard({required this.pool});

  final ScorePool pool;

  Future<void> _openJoinSheet(BuildContext context) async {
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _JoinPoolSheet(pool: pool),
    );

    if (!context.mounted || joined != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pool joined')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final userId = ref.watch(currentUserProvider)?.id;
    final isOwnPool = userId != null && pool.creatorId == userId;
    final canJoin = pool.status == 'open' && !isOwnPool;

    return FzCard(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/pool/${pool.id}');
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FzBadge(
                label: pool.status.toUpperCase(),
                variant: pool.status == 'open'
                    ? FzBadgeVariant.accent
                    : FzBadgeVariant.ghost,
                pulse: pool.status == 'open',
                fontSize: 8,
              ),
              const Spacer(),
              Text(
                formatFET(pool.stake, currency),
                style: FzTypography.scoreCompact(color: FzColors.coral),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pool.matchName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.users, size: 14, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    '${pool.participantsCount} participants',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.zap, size: 14, color: FzColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    formatFET(pool.totalPool, currency),
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CREATOR PREDICTION',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pool.creatorPrediction,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusLabel(isOwnPool),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              if (canJoin)
                FilledButton.icon(
                  onPressed: () => _openJoinSheet(context),
                  icon: const Icon(LucideIcons.swords, size: 16),
                  label: const Text('Join'),
                )
              else
                Icon(LucideIcons.chevronRight, size: 16, color: muted),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(bool isOwnPool) {
    if (isOwnPool && pool.status == 'open') {
      return 'Waiting for opponents';
    }
    if (pool.status == 'settled') {
      return 'Settled';
    }
    if (pool.status == 'open') {
      return 'Open until ${_formatLockTime(pool.lockAt)}';
    }
    return pool.status;
  }

  String _formatLockTime(DateTime lockAt) {
    final hour = lockAt.hour.toString().padLeft(2, '0');
    final minute = lockAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
