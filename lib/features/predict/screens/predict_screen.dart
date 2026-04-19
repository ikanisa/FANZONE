import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/market/launch_market.dart';
import '../../../core/utils/currency_utils.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../../main.dart' show supabaseInitialized;
import '../../../models/match_model.dart';
import '../../../models/pool.dart';
import '../../../models/prediction_slip_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../services/pool_service.dart';
import '../../../services/prediction_slip_service.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';

/// Predict & Pools hub — score pools, active entries, and settled bets.
class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key});

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poolsAsync = ref.watch(poolServiceProvider);
    final entriesAsync = ref.watch(myEntriesProvider);
    final slipsAsync = ref.watch(myPredictionSlipsProvider);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final primaryRegion = ref.watch(primaryMarketRegionProvider);
    final focusTags = ref.watch(marketFocusTagsProvider);
    final launchEventsAsync = ref.watch(homeLaunchEventsProvider);
    final launchChallengesAsync = ref.watch(spotlightChallengesProvider);

    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREDICT',
                            style: FzTypography.display(
                              size: 30,
                              color: isDark
                                  ? FzColors.darkText
                                  : FzColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lock free slips first, then join pools and fan-club challenges when you want FET at stake.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const _CreatePoolSheet(),
                        );
                      },
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Create'),
                      style: FilledButton.styleFrom(
                        backgroundColor: FzColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FzCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: FzColors.accent.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FzColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.zap,
                          color: FzColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Free Slip Ledger',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              slipsAsync.when(
                                data: (slips) {
                                  final active = slips
                                      .where(
                                        (slip) => slip.status == 'submitted',
                                      )
                                      .length;
                                  return '$active submitted';
                                },
                                loading: () => 'Loading...',
                                error: (error, stackTrace) => 'Unavailable',
                              ),
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, size: 18, color: muted),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: GestureDetector(
                  onTap: () => context.push('/predict/jackpot'),
                  child: FzCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    borderColor: FzColors.teal.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FzColors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.trophy,
                            color: FzColors.teal,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weekly Jackpot Challenge',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Predict 10 matches, win 10,000 FET',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.chevronRight, size: 16, color: muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FzCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: FzColors.accent.withValues(alpha: 0.22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2026 MOMENTUM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FzColors.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Predict is now tuned for ${launchRegionLabel(primaryRegion).toLowerCase()} first, while still surfacing the wider World Cup and Champions League conversion window.',
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag
                              in (focusTags.isEmpty
                                      ? defaultFocusTagsForRegion(primaryRegion)
                                      : focusTags.toList())
                                  .take(3))
                            FzBadge(
                              label: launchMomentByTag(tag)?.title ?? tag,
                              color: FzColors.accent.withValues(alpha: 0.14),
                              textColor: FzColors.accent,
                            ),
                        ],
                      ),
                      launchEventsAsync.when(
                        data: (events) {
                          final event = events.firstOrNull;
                          if (event == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Current spotlight: ${event.name}',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      launchChallengesAsync.when(
                        data: (challenges) {
                          if (challenges.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${challenges.length} region-aware global challenges are open right now.',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FzColors.darkSurface2
                        : FzColors.lightSurface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    indicator: BoxDecoration(
                      color: FzColors.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: muted,
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(text: 'SLIPS', height: 32),
                      Tab(text: 'FEATURED', height: 32),
                      Tab(text: 'OPEN', height: 32),
                      Tab(text: 'MINE', height: 32),
                      Tab(text: 'SETTLED', height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _MySlipsView(slipsAsync: slipsAsync),
              _PoolListView(
                poolsAsync: poolsAsync,
                entriesAsync: entriesAsync,
                filter: 'featured',
              ),
              _PoolListView(
                poolsAsync: poolsAsync,
                entriesAsync: entriesAsync,
                filter: 'open',
              ),
              _PoolListView(
                poolsAsync: poolsAsync,
                entriesAsync: entriesAsync,
                filter: 'mine',
              ),
              _PoolListView(
                poolsAsync: poolsAsync,
                entriesAsync: entriesAsync,
                filter: 'settled',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── My Slips View — free solo prediction slips ────────────────────

class _MySlipsView extends StatelessWidget {
  const _MySlipsView({required this.slipsAsync});

  final AsyncValue<List<PredictionSlipModel>> slipsAsync;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return slipsAsync.when(
      data: (slips) {
        if (slips.isEmpty) {
          return StateView.empty(
            title: 'No prediction slips yet',
            subtitle:
                'Browse matches and tap odds to add selections to your slip. Predict for free — no FET required.',
            icon: LucideIcons.fileText,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: slips.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final slip = slips[index];
            return _SlipCard(
              slip: slip,
              isDark: isDark,
              muted: muted,
              textColor: textColor,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => StateView.error(
        title: 'Could not load slips',
        subtitle: 'Pull down to try again.',
      ),
    );
  }
}

class _SlipCard extends ConsumerWidget {
  const _SlipCard({
    required this.slip,
    required this.isDark,
    required this.muted,
    required this.textColor,
  });

  final PredictionSlipModel slip;
  final bool isDark;
  final Color muted;
  final Color textColor;

  Color _statusColor() {
    switch (slip.status) {
      case 'settled_win':
        return FzColors.success;
      case 'settled_loss':
        return FzColors.maltaRed;
      case 'voided':
        return FzColors.amber;
      default:
        return FzColors.accent;
    }
  }

  String _statusLabel() {
    switch (slip.status) {
      case 'settled_win':
        return 'WON';
      case 'settled_loss':
        return 'LOST';
      case 'voided':
        return 'VOIDED';
      default:
        return 'SUBMITTED';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final submitted = slip.submittedAt;
    final dateLabel = submitted != null
        ? '${submitted.day}/${submitted.month}/${submitted.year}'
        : '';

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Selection count badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${slip.selectionCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _statusColor(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${slip.selectionCount} selection${slip.selectionCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FzBadge(label: _statusLabel(), color: _statusColor()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(dateLabel, style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
          // Projected earn
          if (slip.projectedEarnFet > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatFETSigned(
                    slip.projectedEarnFet,
                    currency,
                    positive: true,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FzColors.success,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

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
  // Sort sub-filters for open/featured tabs
  String _sortBy = 'newest'; // newest, pool, participants

  // Sub-filter for mine tab
  String _mineFilter = 'all'; // all, active, won, lost

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return widget.poolsAsync.when(
      data: (pools) {
        final userId = supabaseInitialized
            ? Supabase.instance.client.auth.currentUser?.id
            : null;
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
            // Apply mine sub-filter
            switch (_mineFilter) {
              case 'active':
                filtered = filtered.where((c) => c.status == 'open').toList();
                break;
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
            // Apply sort sub-filter
            _applySortFilter(filtered);
            emptyTitle = 'No open pools';
            emptySubtitle = 'Create a pool or wait for one to open.';
        }

        // Build the list with optional sort chips header
        final showSortChips = widget.filter == 'open';
        final showMineChips = widget.filter == 'mine';

        return Column(
          children: [
            // Sort sub-filters
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
            // Mine sub-filters
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
            // Pool list
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
      default: // newest
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
    final userId = supabaseInitialized
        ? Supabase.instance.client.auth.currentUser?.id
        : null;
    final isOwnPool = userId != null && pool.creatorId == userId;
    final canJoin = pool.status == 'open' && !isOwnPool;

    return FzCard(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/predict/pool/${pool.id}');
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FzBadge(
                label: pool.status.toUpperCase(),
                color: pool.status == 'open' ? FzColors.success : muted,
                textColor: Colors.white,
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
          Row(
            children: [
              Icon(LucideIcons.users, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                '${pool.participantsCount} participants',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.zap, size: 14, color: FzColors.accent),
              const SizedBox(width: 6),
              Text(
                formatFET(pool.totalPool, currency),
                style: TextStyle(fontSize: 12, color: muted),
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

class _JoinPoolSheet extends ConsumerStatefulWidget {
  const _JoinPoolSheet({required this.pool});

  final ScorePool pool;

  @override
  ConsumerState<_JoinPoolSheet> createState() => _JoinPoolSheetState();
}

class _JoinPoolSheetState extends ConsumerState<_JoinPoolSheet> {
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  Future<void> _joinPool() async {
    if (!ref.read(isAuthenticatedProvider)) {
      await showSignInRequiredSheet(
        context,
        title: 'Sign in to join this pool',
        message:
            'Guests can browse pools freely. Phone verification is only required when you want to join one.',
        from: '/predict/pool/${widget.pool.id}',
      );
      return;
    }

    final homeScore = int.tryParse(_homeScoreController.text);
    final awayScore = int.tryParse(_awayScoreController.text);

    if (homeScore == null || awayScore == null) {
      setState(() => _error = 'Enter valid score predictions.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(poolServiceProvider.notifier)
          .joinPool(
            poolId: widget.pool.id,
            homeScore: homeScore,
            awayScore: awayScore,
            stake: widget.pool.stake,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => _error = error.message);
    } on ArgumentError catch (error) {
      setState(() => _error = error.message.toString());
    } on StateError catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not join the pool. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetScaffold(
        title: 'Join pool',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pool.matchName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Stake: ${formatFET(widget.pool.stake, currency)}',
              style: const TextStyle(fontSize: 13, color: FzColors.accent),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _homeScoreController,
                    label: 'Home',
                    enabled: !_submitting,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    controller: _awayScoreController,
                    label: 'Away',
                    enabled: !_submitting,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: FzColors.error)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _joinPool,
                child: Text(_submitting ? 'Joining...' : 'Join pool'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _CreatePoolSheet extends ConsumerStatefulWidget {
  const _CreatePoolSheet();

  @override
  ConsumerState<_CreatePoolSheet> createState() => _CreatePoolSheetState();
}

class _CreatePoolSheetState extends ConsumerState<_CreatePoolSheet> {
  final _stakeController = TextEditingController();
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  late final MatchesFilter _matchFilter;
  String? _selectedMatchId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 14));
    _matchFilter = MatchesFilter(
      dateFrom: _formatDate(start),
      dateTo: _formatDate(end),
      limit: 24,
      ascending: true,
    );
  }

  @override
  void dispose() {
    _stakeController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  Future<void> _createPool() async {
    if (!ref.read(isAuthenticatedProvider)) {
      await showSignInRequiredSheet(
        context,
        title: 'Sign in to create a pool',
        message: 'Phone verification is required to create and manage pools.',
        from: '/predict',
      );
      return;
    }

    final matchId = _selectedMatchId;
    final stake = int.tryParse(_stakeController.text.trim()) ?? 0;
    final homeScore = int.tryParse(_homeScoreController.text.trim());
    final awayScore = int.tryParse(_awayScoreController.text.trim());

    if (matchId == null || matchId.isEmpty) {
      setState(() => _error = 'Select an upcoming match.');
      return;
    }
    if (stake <= 0) {
      setState(() => _error = 'Enter a valid FET stake amount.');
      return;
    }
    if (homeScore == null || awayScore == null) {
      setState(() => _error = 'Enter your score prediction.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(poolServiceProvider.notifier)
          .createPool(
            matchId: matchId,
            homeScore: homeScore,
            awayScore: awayScore,
            stake: stake,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pool created! Waiting for opponents.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final balance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final matchesAsync = ref.watch(matchesProvider(_matchFilter));
    final availableMatches = (matchesAsync.valueOrNull ?? const <MatchModel>[])
        .where((match) => match.isUpcoming)
        .toList(growable: false);
    final selectedMatch = _selectedMatch(availableMatches);
    final canCreatePool =
        !_submitting && matchesAsync.hasValue && availableMatches.isNotEmpty;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    if (_selectedMatchId == null && availableMatches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedMatchId != null) return;
        setState(() => _selectedMatchId = availableMatches.first.id);
      });
    }

    return Container(
      padding: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Create Pool',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a prediction pool. Others can join by matching your stake.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 18),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Match',
                  prefixIcon: Icon(LucideIcons.swords, size: 18, color: muted),
                  errorText: matchesAsync.hasError
                      ? 'Could not load upcoming matches.'
                      : null,
                ),
                child: matchesAsync.when(
                  data: (matches) {
                    final items = matches
                        .where((match) => match.isUpcoming)
                        .toList(growable: false);

                    if (items.isEmpty) {
                      return Text(
                        'No upcoming matches are available to pool yet.',
                        style: TextStyle(fontSize: 13, color: muted),
                      );
                    }

                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedMatch?.id ?? items.first.id,
                        items: items
                            .map(
                              (match) => DropdownMenuItem<String>(
                                value: match.id,
                                child: Text(
                                  '${match.homeTeam} vs ${match.awayTeam}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedMatchId = value;
                                  _error = null;
                                });
                              },
                      ),
                    );
                  },
                  loading: () => Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading upcoming matches...',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                  error: (_, _) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Retry to load matches before creating a pool.',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(matchesProvider(_matchFilter)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedMatch != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Locks before ${_formatMatchWindow(selectedMatch)}',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _stakeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Stake (FET)',
                  hintText: '50',
                  helperText: 'Available: ${formatFET(balance, currency)}',
                  prefixIcon: Icon(LucideIcons.zap, size: 18, color: muted),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'YOUR SCORE PREDICTION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _homeScoreController,
                      label: selectedMatch?.homeTeam ?? 'Home',
                      enabled: !_submitting,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '-',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NumberField(
                      controller: _awayScoreController,
                      label: selectedMatch?.awayTeam ?? 'Away',
                      enabled: !_submitting,
                    ),
                  ),
                ],
              ),
              if ((_error ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FzColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 16,
                        color: FzColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FzColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canCreatePool ? _createPool : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.plus, size: 16),
                  label: Text(_submitting ? 'Creating...' : 'Create Pool'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MatchModel? _selectedMatch(List<MatchModel> matches) {
    for (final match in matches) {
      if (match.id == _selectedMatchId) return match;
    }
    return matches.isNotEmpty ? matches.first : null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatMatchWindow(MatchModel match) {
    final date = match.date;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final kickoff = match.kickoffTime ?? '--:--';
    return '$day/$month at $kickoff';
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  const _SliverAppBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => kTextTabBarHeight;

  @override
  double get maxExtent => kTextTabBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
