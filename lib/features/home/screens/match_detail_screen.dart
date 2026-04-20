import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/feature_flags.dart';
import '../../../models/match_ai_analysis_model.dart';
import '../../../models/match_model.dart';
import '../../../models/match_player_stats_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/crowd_prediction_provider.dart';
import '../../../providers/match_detail_providers.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/predict/accordion_market.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/fz_glass_loader.dart';

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
              icon: Icons.sports_soccer_rounded,
            ),
          );
        }

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
          const Tab(text: 'Insights'),
          const Tab(text: 'Stats'),
          const Tab(text: 'H2H'),
          const Tab(text: 'Lineups'),
        ];
        final views = <Widget>[
          if (flags.predictions) _PredictTab(match: match),
          _InsightsTab(match: match),
          _StatsTab(match: match),
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
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkSurface.withValues(alpha: 0.92)
                      : FzColors.lightSurface.withValues(alpha: 0.92),
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  ),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headerEyebrow.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? FzColors.darkMuted
                              : FzColors.lightMuted,
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? FzColors.darkText
                              : FzColors.lightText,
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
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
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
                      icon: const Icon(Icons.share_rounded, size: 20),
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
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
