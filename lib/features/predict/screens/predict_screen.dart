import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/market/launch_market.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../models/match_model.dart';
import '../../../models/pool.dart';
import '../../../models/prediction_slip_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/pool_service.dart';
import '../../../services/prediction_slip_service.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';

part '../widgets/predict_pool_create_sheet.dart';
part '../widgets/predict_pool_join_sheet.dart';
part '../widgets/predict_pool_list_view.dart';
part '../widgets/predict_slips_view.dart';

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
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
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
                            'POOLS',
                            style: FzTypography.display(
                              size: 30,
                              color: isDark
                                  ? FzColors.darkText
                                  : FzColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open, join, and settle prediction pools with the fastest route from live matches into competition.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      label: 'Create pool',
                      child: IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => const _CreatePoolSheet(),
                          );
                        },
                        tooltip: 'Create pool',
                        icon: const Icon(
                          LucideIcons.plus,
                          size: 18,
                          semanticLabel: 'Create pool',
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: FzColors.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(40, 40),
                          padding: EdgeInsets.zero,
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
                child: Semantics(
                  button: true,
                  label: 'Open weekly jackpot challenge',
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
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: muted,
                          ),
                        ],
                      ),
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
                      Tab(text: 'FEATURED', height: 32),
                      Tab(text: 'OPEN', height: 32),
                      Tab(text: 'MY POOLS', height: 32),
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
