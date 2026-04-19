import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/match_model.dart';
import '../../../models/prediction_slip_model.dart';
import '../../../models/pool.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';

import '../../../providers/matches_provider.dart';
import '../../../services/pool_service.dart';

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
  const PredictScreen({super.key, this.openCreateSheet = false});

  final bool openCreateSheet;

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _hasOpenedCreateSheet = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.openCreateSheet || _hasOpenedCreateSheet) return;
    _hasOpenedCreateSheet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openCreatePoolSheet();
    });
  }

  void _openCreatePoolSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreatePoolSheet(),
    ).whenComplete(() {
      if (!mounted || !widget.openCreateSheet) return;
      context.go('/pools');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poolsAsync = ref.watch(poolServiceProvider);
    final entriesAsync = ref.watch(myEntriesProvider);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

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
                            'Pools',
                            style: FzTypography.display(
                              size: 30,
                              color: isDark
                                  ? FzColors.darkText
                                  : FzColors.lightText,
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
                        onPressed: _openCreatePoolSheet,
                        tooltip: 'Create pool',
                        icon: const Icon(
                          LucideIcons.plus,
                          size: 18,
                          semanticLabel: 'Create pool',
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: FzColors.blue,
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
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
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
