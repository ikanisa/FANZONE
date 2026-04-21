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
import '../../../theme/radii.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/team_crest.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../../widgets/common/fz_glass_loader.dart';

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
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _openCreatePoolFlow() {
    HapticFeedback.selectionClick();
    context.push('/pools/create');
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
                        onPressed: _openCreatePoolFlow,
                        tooltip: 'Create pool',
                        icon: const Icon(
                          LucideIcons.plus,
                          size: 18,
                          semanticLabel: 'Create pool',
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: FzColors.accent2,
                          foregroundColor: FzColors.darkBg,
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
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PoolsTopTab(
                          label: 'Featured',
                          icon: LucideIcons.star,
                          inactiveIconColor: FzColors.accent3,
                          isActive: _tabController.index == 0,
                          onTap: () => _tabController.animateTo(0),
                        ),
                      ),
                      Expanded(
                        child: _PoolsTopTab(
                          label: 'Open',
                          icon: LucideIcons.activity,
                          inactiveIconColor: FzColors.accent,
                          isActive: _tabController.index == 1,
                          onTap: () => _tabController.animateTo(1),
                        ),
                      ),
                      Expanded(
                        child: _PoolsTopTab(
                          label: 'Mine',
                          icon: LucideIcons.swords,
                          inactiveIconColor: muted,
                          isActive: _tabController.index == 2,
                          badgeCount: entriesAsync.valueOrNull?.length ?? 0,
                          onTap: () => _tabController.animateTo(2),
                        ),
                      ),
                      Expanded(
                        child: _PoolsTopTab(
                          label: 'Settled',
                          icon: LucideIcons.trophy,
                          inactiveIconColor: muted,
                          isActive: _tabController.index == 3,
                          onTap: () => _tabController.animateTo(3),
                        ),
                      ),
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

class _PoolsTopTab extends StatelessWidget {
  const _PoolsTopTab({
    required this.label,
    required this.icon,
    required this.inactiveIconColor,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final Color inactiveIconColor;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? FzColors.darkText : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? FzColors.darkBg : inactiveIconColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isActive ? FzColors.darkBg : muted,
                  ),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? FzColors.darkBg : FzColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isActive ? FzColors.darkText : FzColors.darkBg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
