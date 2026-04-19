import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_config.dart';
import '../../../models/match_ai_analysis_model.dart';
import '../../../models/match_model.dart';
import '../../../models/match_player_stats_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/match_detail_providers.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/standings_provider.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/match/standings_table.dart';
import '../../../widgets/predict/accordion_market.dart';
import '../../../widgets/social/feed_chat.dart';

part '../widgets/match_detail/ai_analysis_card.dart';
part '../widgets/match_detail/h2h_table_predict_tabs.dart';
part '../widgets/match_detail/lineups_tab.dart';
part '../widgets/match_detail/match_hero.dart';
part '../widgets/match_detail/overview_tab.dart';
part '../widgets/match_detail/stats_support.dart';
part '../widgets/match_detail/stats_tab.dart';
part '../widgets/match_detail/table_tab.dart';

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
        final standingsAsync = ref.watch(
          competitionStandingsProvider(
            CompetitionStandingsFilter(
              competitionId: match.competitionId,
              season: match.season,
            ),
          ),
        );
        final relatedMatchesAsync = ref.watch(
          competitionMatchesProvider(match.competitionId),
        );
        final matchAlertsAsync = ref.watch(matchAlertEnabledProvider(match.id));
        final favourites =
            ref.watch(favouritesProvider).valueOrNull ??
            const FavouritesState();
        final matchAlertsEnabled = matchAlertsAsync.valueOrNull ?? false;
        final tabs = <Tab>[
          if (AppConfig.enablePredictions) const Tab(text: 'Predict'),
          const Tab(text: 'Overview'),
          const Tab(text: 'Lineups'),
          const Tab(text: 'Stats'),
          const Tab(text: 'H2H'),
          const Tab(text: 'Table'),
          if (AppConfig.enableSocialFeed) const Tab(text: 'Chat'),
        ];
        final views = <Widget>[
          if (AppConfig.enablePredictions) _PredictTab(match: match),
          _OverviewTab(
            match: match,
            relatedMatchesAsync: relatedMatchesAsync,
            competitionName:
                competitionAsync.valueOrNull?.name ?? match.competitionId,
          ),
          _LineupsTab(match: match),
          _StatsTab(match: match),
          _H2HTab(match: match),
          _TableTab(
            standingsAsync: standingsAsync,
            highlightTeamIds: {
              if (match.homeTeamId != null) match.homeTeamId!,
              if (match.awayTeamId != null) match.awayTeamId!,
            },
          ),
          if (AppConfig.enableSocialFeed)
            FeedChat(channelType: 'match', channelId: match.id),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  title: Text(
                    competitionAsync.valueOrNull?.shortName ?? 'Match',
                  ),
                  actions: [
                    IconButton(
                      tooltip:
                          favourites.isCompetitionFavourite(match.competitionId)
                          ? 'Unfollow competition'
                          : 'Follow competition',
                      onPressed: () => ref
                          .read(favouritesProvider.notifier)
                          .toggleCompetition(match.competitionId),
                      icon: Icon(
                        favourites.isCompetitionFavourite(match.competitionId)
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color:
                            favourites.isCompetitionFavourite(
                              match.competitionId,
                            )
                            ? FzColors.coral
                            : null,
                      ),
                    ),
                    IconButton(
                      tooltip: matchAlertsEnabled
                          ? 'Disable match alerts'
                          : 'Enable match alerts',
                      onPressed: () async {
                        HapticFeedback.selectionClick();
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
                        color: matchAlertsEnabled ? FzColors.accent : null,
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
                SliverToBoxAdapter(
                  child: _MatchHero(
                    match: match,
                    competitionLabel:
                        competitionAsync.valueOrNull?.name ??
                        match.competitionId,
                  ),
                ),
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
