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
  String _sortBy = 'ending_soon';
  String _mineFilter = 'open';

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
            filtered = switch (_mineFilter) {
              'locked' =>
                filtered.where((pool) => pool.status == 'locked').toList(),
              'settled' =>
                filtered.where((pool) => pool.status == 'settled').toList(),
              'voided' =>
                filtered.where((pool) => pool.status == 'void').toList(),
              _ => filtered.where((pool) => pool.status == 'open').toList(),
            };
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
                      label: 'Soon',
                      selected: _sortBy == 'ending_soon',
                      onTap: () => setState(() => _sortBy = 'ending_soon'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Big Pool',
                      selected: _sortBy == 'high_pool',
                      onTap: () => setState(() => _sortBy = 'high_pool'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Entries',
                      selected: _sortBy == 'most_participants',
                      onTap: () =>
                          setState(() => _sortBy = 'most_participants'),
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
                      label: 'Open',
                      selected: _mineFilter == 'open',
                      onTap: () => setState(() => _mineFilter = 'open'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Locked',
                      selected: _mineFilter == 'locked',
                      onTap: () => setState(() => _mineFilter = 'locked'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Settled',
                      selected: _mineFilter == 'settled',
                      onTap: () => setState(() => _mineFilter = 'settled'),
                      isDark: isDark,
                      muted: muted,
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Voided',
                      selected: _mineFilter == 'voided',
                      onTap: () => setState(() => _mineFilter = 'voided'),
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
                      icon: LucideIcons.swords,
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
      case 'high_pool':
        list.sort((a, b) => b.totalPool.compareTo(a.totalPool));
        break;
      case 'most_participants':
        list.sort((a, b) => b.participantsCount.compareTo(a.participantsCount));
        break;
      default:
        list.sort((a, b) => a.lockAt.compareTo(b.lockAt));
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
              ? FzColors.primary.withValues(alpha: 0.15)
              : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? FzColors.primary.withValues(alpha: 0.4)
                : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? FzColors.primary : muted,
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

    // Parse team names from matchName
    final parts = pool.matchName.split(
      RegExp(r'\s+vs?\s+', caseSensitive: false),
    );
    final homeTeam = parts.isNotEmpty ? parts[0].trim() : 'Home';
    final awayTeam = parts.length > 1 ? parts[1].trim() : 'Away';

    return FzCard(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/pool/${pool.id}');
      },
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient status bar at top
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(FzRadii.card),
              ),
              gradient: LinearGradient(
                colors: pool.status == 'open'
                    ? [FzColors.primary, FzColors.cyan]
                    : pool.status == 'settled'
                    ? [FzColors.secondary, FzColors.danger]
                    : [FzColors.darkMuted, FzColors.darkBorder],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badges row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FzBadge(
                            label: _formatLockTime(pool.lockAt),
                            variant: FzBadgeVariant.ghost,
                            fontSize: 9,
                            icon: LucideIcons.clock,
                          ),
                          FzBadge(
                            label: pool.status.toUpperCase(),
                            variant: pool.status == 'open'
                                ? FzBadgeVariant.primary
                                : pool.status == 'settled'
                                ? FzBadgeVariant.secondary
                                : FzBadgeVariant.ghost,
                            pulse: pool.status == 'open',
                            fontSize: 9,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('STAKE', style: FzTypography.metaLabel()),
                        Text(
                          formatFET(pool.stake, currency),
                          style: FzTypography.score(
                            size: 16,
                            color: FzColors.coral,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Team names with crests
                _TeamRow(name: homeTeam),
                const SizedBox(height: 8),
                _TeamRow(name: awayTeam),
                const SizedBox(height: 12),
                // Meta row
                Row(
                  children: [
                    Icon(LucideIcons.users, size: 12, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      '${pool.participantsCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      LucideIcons.zap,
                      size: 12,
                      color: FzColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatFET(pool.totalPool, currency),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    const Spacer(),
                    if (canJoin)
                      FilledButton.icon(
                        onPressed: () => _openJoinSheet(context),
                        icon: const Icon(LucideIcons.swords, size: 14),
                        label: const Text('JOIN'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      )
                    else
                      Icon(LucideIcons.chevronRight, size: 16, color: muted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLockTime(DateTime lockAt) {
    final local = lockAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Inline team row with crest — matches reference's TeamLogo + name layout.
class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: FzColors.darkSurface3,
            shape: BoxShape.circle,
            border: Border.all(color: FzColors.darkBorder),
          ),
          child: const Icon(
            LucideIcons.shield,
            size: 12,
            color: FzColors.darkMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
