import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/feature_flags.dart';
import '../../../models/live_match_event.dart';
import '../../../models/match_ai_analysis_model.dart';
import '../../../models/match_event_model.dart';
import '../../../models/match_model.dart';
import '../../../models/match_player_stats_model.dart';
import '../../../models/prediction_market_catalog_item.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/crowd_prediction_provider.dart';
import '../../../providers/match_detail_providers.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/prediction_slip_provider.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_glass_loader.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

part '../widgets/match_detail/ai_analysis_card.dart';
part '../widgets/match_detail/crowd_prediction_bar.dart';
part '../widgets/match_detail/h2h_table_predict_tabs.dart';
part '../widgets/match_detail/insights_tab.dart';
part '../widgets/match_detail/lineups_tab.dart';
part '../widgets/match_detail/match_hero.dart';
part '../widgets/match_detail/overview_tab.dart';
part '../widgets/match_detail/stats_support.dart';
part '../widgets/match_detail/stats_tab.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchDetailProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Match')),
            body: StateView.empty(
              title: 'Match not found',
              subtitle: 'Return to scores.',
              icon: LucideIcons.circle,
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
        final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
        final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
        final text = isDark ? FzColors.darkText : FzColors.lightText;
        final competitionAsync = ref.watch(
          competitionProvider(match.competitionId),
        );
        final matchAlertsAsync = ref.watch(matchAlertEnabledProvider(match.id));
        final matchAlertsEnabled = matchAlertsAsync.valueOrNull ?? false;
        final competitionLabel =
            competitionAsync.valueOrNull?.shortName ??
            competitionAsync.valueOrNull?.name ??
            match.competitionId;
        final roundLabel = match.round?.trim();
        final headerEyebrow = roundLabel != null && roundLabel.isNotEmpty
            ? '$competitionLabel · $roundLabel'
            : competitionLabel;
        final flags = ref.watch(featureFlagsProvider);
        final tabs = <Tab>[
          if (flags.predictions) const Tab(text: 'Predict'),
          if (flags.aiAnalysis)
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.sparkles, size: 14),
                  SizedBox(width: 6),
                  Text('Insights'),
                ],
              ),
            ),
          if (flags.advancedStats) const Tab(text: 'Stats'),
          const Tab(text: 'H2H'),
          const Tab(text: 'Lineups'),
        ];
        final views = <Widget>[
          if (flags.predictions) _PredictTab(match: match),
          if (flags.aiAnalysis) _InsightsTab(match: match),
          if (flags.advancedStats) _StatsTab(match: match),
          _H2HTab(match: match),
          _LineupsTab(match: match),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  centerTitle: true,
                  backgroundColor: surface.withValues(alpha: 0.88),
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: border),
                  ),
                  leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.chevronLeft, size: 24),
                  ),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headerEyebrow.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: muted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${match.homeTeam} vs ${match.awayTeam}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: text,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: matchAlertsEnabled
                          ? 'Disable match alerts'
                          : 'Enable match alerts',
                      onPressed: () async {
                        unawaited(HapticFeedback.selectionClick());
                        final nextValue = !matchAlertsEnabled;
                        await ref
                            .read(notificationServiceProvider.notifier)
                            .setMatchAlerts(
                              matchId: match.id,
                              enabled: nextValue,
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              nextValue
                                  ? 'Match alerts enabled for ${match.homeTeam} vs ${match.awayTeam}'
                                  : 'Match alerts disabled',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(
                        matchAlertsEnabled
                            ? LucideIcons.bellRing
                            : LucideIcons.bell,
                        size: 22,
                        color: matchAlertsEnabled ? FzColors.primary : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Share match',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final score = match.scoreDisplay ?? 'vs';
                        SharePlus.instance.share(
                          ShareParams(
                            text:
                                '${match.homeTeam} $score ${match.awayTeam} — FANZONE',
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.share2, size: 20),
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: _MatchHero(match: match)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      overlayColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      dividerColor: border,
                      indicatorColor: FzColors.primary,
                      indicatorWeight: 2,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: tabs,
                    ),
                  ),
                ),
              ],
              body: TabBarView(children: views),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: ScoresPageSkeleton()),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Match')),
        body: StateView.error(
          title: 'Match unavailable',
          subtitle: 'Try again later.',
          onRetry: () => ref.invalidate(matchDetailProvider(matchId)),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
