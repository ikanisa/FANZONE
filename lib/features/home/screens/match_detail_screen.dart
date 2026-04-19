import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_config.dart';
import '../../../models/match_model.dart';
import '../../../models/match_player_stats_model.dart';
import '../../../models/match_ai_analysis_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/standings_provider.dart';
import '../../../providers/match_detail_providers.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/predict/accordion_market.dart';
import '../../../widgets/match/standings_table.dart';
import '../../../widgets/social/feed_chat.dart';

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
          initialIndex: AppConfig.enablePredictions ? 0 : 0,
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
                    // M5: Match Notification Bell
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
                    // M4: Share match action
                    IconButton(
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

class _MatchHero extends StatelessWidget {
  const _MatchHero({required this.match, required this.competitionLabel});

  final MatchModel match;
  final String competitionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          FzBadge(label: competitionLabel.toUpperCase(), fontSize: 9),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroTeam(name: match.homeTeam)),
              SizedBox(
                width: 92,
                child: Column(
                  children: [
                    Text(
                      match.scoreDisplay ?? 'VS',
                      style: FzTypography.scoreLarge(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusLabel(match),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? FzColors.darkMuted
                            : FzColors.lightMuted,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _HeroTeam(name: match.awayTeam)),
            ],
          ),
          if (match.isLive) ...[
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateFormat.Hm().format(DateTime.now())}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkMuted
                    : FzColors.lightMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(MatchModel match) {
    if (match.isLive) return 'LIVE';
    if (match.isFinished) return 'FULL TIME';
    return match.kickoffTime ?? 'SCHEDULED';
  }
}

class _HeroTeam extends StatelessWidget {
  const _HeroTeam({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamAvatar(name: name, size: 54),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.match,
    required this.relatedMatchesAsync,
    required this.competitionName,
  });

  final MatchModel match;
  final AsyncValue<List<MatchModel>> relatedMatchesAsync;
  final String competitionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final dateLabel = DateFormat('dd MMM yyyy').format(match.date);
    final factValues = <({String label, String value})>[
      (label: 'Competition', value: competitionName),
      (label: 'Round', value: match.round ?? 'Fixture'),
      (label: 'Date', value: dateLabel),
      (label: 'Kickoff', value: match.kickoffTime ?? '--:--'),
      (label: 'Venue', value: match.venue ?? 'TBC'),
      (label: 'Status', value: match.kickoffLabel),
    ];

    final liveEventsAsync = ref.watch(liveMatchEventsStreamProvider(match.id));
    final liveEvents = liveEventsAsync.valueOrNull ?? [];

    // Build event timeline from realtime stream or fallback to basic score data
    final events = <_MatchEvent>[];

    if (liveEvents.isNotEmpty) {
      // Use our shiny new real-time AI populated data
      for (final ev in liveEvents.reversed) {
        events.add(
          _MatchEvent(
            minute: ev.minute != null ? '${ev.minute}\'' : '--',
            description: ev.eventType == 'GOAL'
                ? 'Goal'
                : (ev.eventType == 'YELLOW_CARD'
                      ? 'Yellow Card'
                      : (ev.eventType == 'RED_CARD' ? 'Red Card' : 'Sub')),
            icon: ev.eventType == 'GOAL'
                ? Icons.sports_soccer_rounded
                : (ev.eventType == 'SUBSTITUTION'
                      ? Icons.sync_rounded
                      : Icons.style_rounded),
            isHome: ev.team == match.homeTeam,
            color: ev.eventType == 'RED_CARD'
                ? Colors.red
                : (ev.eventType == 'YELLOW_CARD'
                      ? Colors.amber
                      : (isDark ? Colors.white : Colors.black87)),
          ),
        );
      }
    } else {
      // Fallback heuristic scoring
      if (match.htHome != null && match.htAway != null) {
        for (var i = 0; i < match.htHome!; i++) {
          events.add(
            _MatchEvent(
              minute: '${15 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: true,
              color: FzColors.accent,
            ),
          );
        }
        for (var i = 0; i < match.htAway!; i++) {
          events.add(
            _MatchEvent(
              minute: '${20 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: false,
              color: FzColors.accent,
            ),
          );
        }
        events.add(
          _MatchEvent(
            minute: 'HT',
            description: '${match.htHome} - ${match.htAway}',
            icon: Icons.access_time_rounded,
            isHome: true,
            color: muted,
          ),
        );
      }
      if (match.ftHome != null && match.ftAway != null) {
        final secondHalfHome = match.ftHome! - (match.htHome ?? 0);
        final secondHalfAway = match.ftAway! - (match.htAway ?? 0);
        for (var i = 0; i < secondHalfHome; i++) {
          events.add(
            _MatchEvent(
              minute: '${55 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: true,
              color: FzColors.accent,
            ),
          );
        }
        for (var i = 0; i < secondHalfAway; i++) {
          events.add(
            _MatchEvent(
              minute: '${60 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: false,
              color: FzColors.accent,
            ),
          );
        }
        events.add(
          _MatchEvent(
            minute: 'FT',
            description: '${match.ftHome} - ${match.ftAway}',
            icon: Icons.flag_rounded,
            isHome: true,
            color: muted,
          ),
        );
      }
    }

    // AI Analysis — show before kickoff
    final aiAnalysisAsync = ref.watch(matchAiAnalysisProvider(match.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── AI Pre-Match Analysis Card ──
        if (match.isUpcoming || match.isLive)
          aiAnalysisAsync.when(
            data: (analysis) {
              if (analysis == null || !analysis.isValid) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _AiAnalysisCard(analysis: analysis, match: match),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),

        // Event timeline (M1)
        if (events.isNotEmpty) ...[
          Text(
            'Match Events',
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 10),
          FzCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: events.asMap().entries.map((entry) {
                final event = entry.value;
                final isLast = entry.key == events.length - 1;
                return _EventTimelineRow(
                  event: event,
                  homeTeam: match.homeTeam,
                  awayTeam: match.awayTeam,
                  isLast: isLast,
                  isDark: isDark,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
        ],
        MatchFactsGrid(facts: factValues),
        const SizedBox(height: 18),
        Text(
          'Related',
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(height: 10),
        relatedMatchesAsync.when(
          data: (matches) {
            final related = matches
                .where((item) => item.id != match.id)
                .take(5)
                .toList();
            if (related.isEmpty) {
              return FzCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No related fixtures.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                  ),
                ),
              );
            }
            return Column(
              children: related
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FzCard(
                        padding: EdgeInsets.zero,
                        child: MatchListRow(
                          match: item,
                          onTap: () => context.push('/match/${item.id}'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const FzCard(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MatchEvent {
  final String minute;
  final String description;
  final IconData icon;
  final bool isHome;
  final Color color;

  const _MatchEvent({
    required this.minute,
    required this.description,
    required this.icon,
    required this.isHome,
    required this.color,
  });
}

class _EventTimelineRow extends StatelessWidget {
  const _EventTimelineRow({
    required this.event,
    required this.homeTeam,
    required this.awayTeam,
    required this.isLast,
    required this.isDark,
  });

  final _MatchEvent event;
  final String homeTeam;
  final String awayTeam;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          // Minute badge
          SizedBox(
            width: 40,
            child: Text(
              event.minute,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: event.color,
                fontFamily: 'JetBrains Mono',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: event.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Event description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(event.icon, size: 14, color: event.color),
                    const SizedBox(width: 6),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? FzColors.darkText : FzColors.lightText,
                      ),
                    ),
                  ],
                ),
                if (event.description == 'Goal')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event.isHome ? homeTeam : awayTeam,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lineups Tab (P2: Real Player Data) ─────────────────────────────

class _LineupsTab extends ConsumerWidget {
  const _LineupsTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final playersAsync = ref.watch(matchPlayerStatsProvider(match.id));

    return playersAsync.when(
      data: (players) {
        if (players.isEmpty) {
          return Center(
            child: StateView.empty(
              title: match.isUpcoming
                  ? 'Lineups not available yet'
                  : 'Lineups unavailable',
              subtitle: match.isUpcoming
                  ? 'Starting XIs are announced roughly 1h before kickoff.'
                  : 'Lineup data is not available for this match.',
              icon: Icons.people_outline_rounded,
            ),
          );
        }

        final homePlayers =
            players.where((p) => p.teamId == match.homeTeamId).toList()
              ..sort((a, b) {
                if (a.isStarter != b.isStarter) return a.isStarter ? -1 : 1;
                return (b.rating ?? 0).compareTo(a.rating ?? 0);
              });
        final awayPlayers =
            players.where((p) => p.teamId == match.awayTeamId).toList()
              ..sort((a, b) {
                if (a.isStarter != b.isStarter) return a.isStarter ? -1 : 1;
                return (b.rating ?? 0).compareTo(a.rating ?? 0);
              });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PlayerSection(
              teamName: match.homeTeam,
              players: homePlayers,
              isDark: isDark,
              muted: muted,
            ),
            const SizedBox(height: 24),
            _PlayerSection(
              teamName: match.awayTeam,
              players: awayPlayers,
              isDark: isDark,
              muted: muted,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => StateView.error(
        title: 'Could not load lineups',
        onRetry: () => ref.invalidate(matchPlayerStatsProvider(match.id)),
      ),
    );
  }
}

class _PlayerSection extends StatelessWidget {
  const _PlayerSection({
    required this.teamName,
    required this.players,
    required this.isDark,
    required this.muted,
  });

  final String teamName;
  final List<MatchPlayerStats> players;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final starters = players.where((p) => p.isStarter).toList();
    final subs = players.where((p) => !p.isStarter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TeamAvatar(name: teamName, size: 24),
            const SizedBox(width: 10),
            Text(
              teamName.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FzCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (var i = 0; i < starters.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                  ),
                _PlayerRow(player: starters[i], isDark: isDark, muted: muted),
              ],
            ],
          ),
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'SUBSTITUTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          FzCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < subs.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  _PlayerRow(player: subs[i], isDark: isDark, muted: muted),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.isDark,
    required this.muted,
  });

  final MatchPlayerStats player;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final ratingColor = player.rating == null
        ? muted
        : player.rating! >= 7.5
        ? FzColors.success
        : player.rating! >= 6.0
        ? FzColors.coral
        : FzColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Number
          SizedBox(
            width: 28,
            child: Text(
              player.playerNumber?.toString() ?? '--',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Name + position
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.playerName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (player.position != null)
                  Text(
                    player.positionLabel,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
          ),
          // Goal/assist badges
          if (player.goals > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sports_soccer_rounded,
                    size: 12,
                    color: FzColors.accent,
                  ),
                  if (player.goals > 1)
                    Text(
                      ' x${player.goals}',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                ],
              ),
            ),
          if (player.assists > 0)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.assistant_rounded,
                size: 12,
                color: FzColors.amber,
              ),
            ),
          if (player.yellowCards > 0)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.square_rounded, size: 10, color: Colors.amber),
            ),
          if (player.redCards > 0)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.square_rounded, size: 10, color: Colors.red),
            ),
          // Rating badge
          if (player.rating != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ratingColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                player.rating!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ratingColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Stats Tab (P2: Advanced Stats from Supabase) ──────────────────

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final advancedAsync = ref.watch(matchAdvancedStatsProvider(match.id));

    // Derive fallback stats from score data
    final hasScores = match.ftHome != null && match.ftAway != null;
    final totalHome = match.ftHome ?? 0;
    final totalAway = match.ftAway ?? 0;

    return advancedAsync.when(
      data: (stats) {
        if (stats == null || !stats.hasData) {
          // Fallback to basic score-derived stats
          if (!hasScores && !match.isLive) {
            return Center(
              child: StateView.empty(
                title: 'Stats not available yet',
                subtitle: 'Statistics appear after kickoff.',
                icon: Icons.bar_chart_rounded,
              ),
            );
          }
          return _BasicStatsView(
            match: match,
            isDark: isDark,
            muted: muted,
            totalHome: totalHome,
            totalAway: totalAway,
          );
        }

        // Rich stats view with advanced data
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── xG Section ──
            if (stats.homeXg != null && stats.awayXg != null) ...[
              Text(
                'Expected Goals (xG)',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 12),
              FzCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            stats.homeXg!.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: stats.homeXg! > stats.awayXg!
                                  ? FzColors.accent
                                  : (isDark
                                        ? FzColors.darkText
                                        : FzColors.lightText),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            match.homeTeam,
                            style: TextStyle(fontSize: 11, color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: FzColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'xG',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: FzColors.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            stats.awayXg!.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: stats.awayXg! > stats.homeXg!
                                  ? FzColors.accent
                                  : (isDark
                                        ? FzColors.darkText
                                        : FzColors.lightText),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            match.awayTeam,
                            style: TextStyle(fontSize: 11, color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ── Possession Ring ──
            if (stats.homePossession != null) ...[
              Text(
                'Possession',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 12),
              FzCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${stats.homePossession}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: FzColors.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.homeTeam,
                          style: TextStyle(fontSize: 11, color: muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _PossessionRingPainter(
                          homePercent: stats.homePossession!,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${stats.awayPossession ?? (100 - stats.homePossession!)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? FzColors.darkText
                                : FzColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.awayTeam,
                          style: TextStyle(fontSize: 11, color: muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ── Dual Stat Bars ──
            Text(
              'Match Statistics',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DualStatBar(
                    label: 'Goals',
                    leftValue: totalHome.toDouble(),
                    rightValue: totalAway.toDouble(),
                    leftLabel: '$totalHome',
                    rightLabel: '$totalAway',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Shots',
                    leftValue: stats.homeShots.toDouble(),
                    rightValue: stats.awayShots.toDouble(),
                    leftLabel: '${stats.homeShots}',
                    rightLabel: '${stats.awayShots}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Shots on Target',
                    leftValue: stats.homeShotsOnTarget.toDouble(),
                    rightValue: stats.awayShotsOnTarget.toDouble(),
                    leftLabel: '${stats.homeShotsOnTarget}',
                    rightLabel: '${stats.awayShotsOnTarget}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Corners',
                    leftValue: stats.homeCorners.toDouble(),
                    rightValue: stats.awayCorners.toDouble(),
                    leftLabel: '${stats.homeCorners}',
                    rightLabel: '${stats.awayCorners}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Fouls',
                    leftValue: stats.homeFouls.toDouble(),
                    rightValue: stats.awayFouls.toDouble(),
                    leftLabel: '${stats.homeFouls}',
                    rightLabel: '${stats.awayFouls}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Yellow Cards',
                    leftValue: stats.homeYellowCards.toDouble(),
                    rightValue: stats.awayYellowCards.toDouble(),
                    leftLabel: '${stats.homeYellowCards}',
                    rightLabel: '${stats.awayYellowCards}',
                    isDark: isDark,
                  ),
                  if (stats.homeRedCards > 0 || stats.awayRedCards > 0) ...[
                    const SizedBox(height: 14),
                    _DualStatBar(
                      label: 'Red Cards',
                      leftValue: stats.homeRedCards.toDouble(),
                      rightValue: stats.awayRedCards.toDouble(),
                      leftLabel: '${stats.homeRedCards}',
                      rightLabel: '${stats.awayRedCards}',
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Data source + refresh time
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Source',
                    value: stats.dataSource,
                    muted: muted,
                  ),
                  if (stats.refreshedAt != null)
                    _InfoRow(
                      label: 'Updated',
                      value: DateFormat(
                        'HH:mm, d MMM',
                      ).format(stats.refreshedAt!),
                      muted: muted,
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => _BasicStatsView(
        match: match,
        isDark: isDark,
        muted: muted,
        totalHome: totalHome,
        totalAway: totalAway,
      ),
    );
  }
}

/// Fallback basic stats (score-only) when advanced data is unavailable.
class _BasicStatsView extends StatelessWidget {
  const _BasicStatsView({
    required this.match,
    required this.isDark,
    required this.muted,
    required this.totalHome,
    required this.totalAway,
  });

  final MatchModel match;
  final bool isDark;
  final Color muted;
  final int totalHome;
  final int totalAway;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Match Statistics',
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(height: 12),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _DualStatBar(
                label: 'Goals',
                leftValue: totalHome.toDouble(),
                rightValue: totalAway.toDouble(),
                leftLabel: '$totalHome',
                rightLabel: '$totalAway',
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _DualStatBar(
                label: 'Half-Time',
                leftValue: (match.htHome ?? 0).toDouble(),
                rightValue: (match.htAway ?? 0).toDouble(),
                leftLabel: '${match.htHome ?? 0}',
                rightLabel: '${match.htAway ?? 0}',
                isDark: isDark,
              ),
              if (match.etHome != null) ...[
                const SizedBox(height: 16),
                _DualStatBar(
                  label: 'Extra Time',
                  leftValue: match.etHome!.toDouble(),
                  rightValue: (match.etAway ?? 0).toDouble(),
                  leftLabel: '${match.etHome}',
                  rightLabel: '${match.etAway ?? 0}',
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match Info',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Season', value: match.season, muted: muted),
              _InfoRow(label: 'Source', value: match.dataSource, muted: muted),
              if (match.venue != null)
                _InfoRow(label: 'Venue', value: match.venue!, muted: muted),
            ],
          ),
        ),
      ],
    );
  }
}

/// Possession donut ring painter.
class _PossessionRingPainter extends CustomPainter {
  _PossessionRingPainter({required this.homePercent, required this.isDark});

  final int homePercent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;
    final bgPaint = Paint()
      ..color = (isDark ? FzColors.darkBorder : FzColors.lightBorder)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final homePaint = Paint()
      ..color = FzColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    final sweepAngle = (homePercent / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      homePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PossessionRingPainter oldDelegate) =>
      oldDelegate.homePercent != homePercent || oldDelegate.isDark != isDark;
}

// ─── H2H Tab (P1-M3) ────────────────────────────────────────────

class _H2HTab extends ConsumerWidget {
  const _H2HTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final matchesAsync = ref.watch(
      competitionMatchesProvider(match.competitionId),
    );

    return matchesAsync.when(
      data: (allMatches) {
        // Find past meetings between these two teams
        final meetings = allMatches.where((m) {
          if (!m.isFinished) return false;
          if (m.id == match.id) return false;
          final teams = {m.homeTeam, m.awayTeam};
          return teams.contains(match.homeTeam) &&
              teams.contains(match.awayTeam);
        }).toList()..sort((a, b) => b.date.compareTo(a.date));
        final recent = meetings.take(5).toList();

        // Recent form for each team (last 5 finished matches)
        List<String> formGuide(String teamName) {
          return allMatches
              .where(
                (m) =>
                    m.isFinished &&
                    (m.homeTeam == teamName || m.awayTeam == teamName),
              )
              .take(5)
              .map((m) {
                final isHome = m.homeTeam == teamName;
                final scored = isHome ? (m.ftHome ?? 0) : (m.ftAway ?? 0);
                final conceded = isHome ? (m.ftAway ?? 0) : (m.ftHome ?? 0);
                if (scored > conceded) return 'W';
                if (scored < conceded) return 'L';
                return 'D';
              })
              .toList();
        }

        final homeForm = formGuide(match.homeTeam);
        final awayForm = formGuide(match.awayTeam);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Recent form
            Text(
              'Recent Form',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FormRow(
                    teamName: match.homeTeam,
                    form: homeForm,
                    isDark: isDark,
                    muted: muted,
                  ),
                  const SizedBox(height: 12),
                  _FormRow(
                    teamName: match.awayTeam,
                    form: awayForm,
                    isDark: isDark,
                    muted: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Last meetings
            Text(
              'Last Meetings',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              FzCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No previous meetings found.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              )
            else
              ...recent.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FzCard(
                    padding: EdgeInsets.zero,
                    child: MatchListRow(
                      match: m,
                      onTap: () => context.push('/match/${m.id}'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => StateView.error(
        title: 'H2H unavailable',
        onRetry: () =>
            ref.invalidate(competitionMatchesProvider(match.competitionId)),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.teamName,
    required this.form,
    required this.isDark,
    required this.muted,
  });

  final String teamName;
  final List<String> form;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamAvatar(name: teamName, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            teamName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: form.map((result) {
            return Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: _formColor(result),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  result,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _formColor(String result) {
    switch (result) {
      case 'W':
        return FzColors.success;
      case 'L':
        return FzColors.danger;
      default:
        return const Color(0xFF6B7280); // gray for draw
    }
  }
}

class _DualStatBar extends StatelessWidget {
  const _DualStatBar({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    required this.leftLabel,
    required this.rightLabel,
    required this.isDark,
  });

  final String label;
  final double leftValue;
  final double rightValue;
  final String leftLabel;
  final String rightLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final total = leftValue + rightValue;
    final leftFraction = total > 0 ? leftValue / total : 0.5;
    final rightFraction = total > 0 ? rightValue / total : 0.5;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final leftWins = leftValue > rightValue;
    final rightWins = rightValue > leftValue;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: leftWins
                    ? FzColors.accent
                    : (isDark ? FzColors.darkText : FzColors.lightText),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            Text(
              rightLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: rightWins
                    ? FzColors.accent
                    : (isDark ? FzColors.darkText : FzColors.lightText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: (leftFraction * 100).round().clamp(5, 95),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: leftWins
                      ? FzColors.accent
                      : muted.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: (rightFraction * 100).round().clamp(5, 95),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: rightWins
                      ? FzColors.accent
                      : muted.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.muted,
  });

  final String label;
  final String value;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.standingsAsync,
    required this.highlightTeamIds,
  });

  final AsyncValue<List<dynamic>> standingsAsync;
  final Set<String> highlightTeamIds;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        standingsAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return StateView.empty(
                title: 'No table',
                subtitle: 'Standings unavailable.',
                icon: Icons.table_rows_rounded,
              );
            }
            return StandingsTable(
              rows: rows.cast(),
              highlightTeamIds: highlightTeamIds,
              onTapTeam: (teamId) => context.push('/clubs/team/$teamId'),
            );
          },
          loading: () => const FzCard(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => StateView.empty(
            title: 'No table',
            subtitle: 'Standings unavailable.',
            icon: Icons.table_rows_rounded,
          ),
        ),
      ],
    );
  }
}

class _PredictTab extends StatelessWidget {
  const _PredictTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    if (match.isFinished) {
      return StateView.empty(
        title: 'Markets Closed',
        subtitle: 'This match has ended.',
        icon: Icons.lock_clock,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        MatchResultMarket(match: match),
        CorrectScoreMarket(match: match),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prediction rules',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              Text(
                'Markets lock at kick-off. Settlements are based on the official full-time score once the match is final.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkMuted
                      : FzColors.lightMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── AI Analysis Card ─────────────────────────────────────────────

class _AiAnalysisCard extends StatelessWidget {
  const _AiAnalysisCard({required this.analysis, required this.match});

  final MatchAiAnalysis analysis;
  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FzColors.accent.withValues(alpha: 0.15),
                  FzColors.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FzColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: FzColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Match Analysis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Powered by ${analysis.modelVersion}',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                // Confidence badge
                if (analysis.confidenceScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: FzColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      analysis.confidenceLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Prediction outcome
          if (analysis.predictedOutcome != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREDICTED OUTCOME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analysis.outcomeLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (analysis.predictedScoreDisplay != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                      child: Text(
                        analysis.predictedScoreDisplay!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Form summaries
          if (analysis.homeFormSummary != null ||
              analysis.awayFormSummary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECENT FORM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (analysis.homeFormSummary != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${match.homeTeam}: ${analysis.homeFormSummary}',
                        style: TextStyle(fontSize: 12, color: textColor),
                      ),
                    ),
                  if (analysis.awayFormSummary != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${match.awayTeam}: ${analysis.awayFormSummary}',
                        style: TextStyle(fontSize: 12, color: textColor),
                      ),
                    ),
                ],
              ),
            ),

          // Key factors
          if (analysis.keyFactors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KEY FACTORS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...analysis.keyFactors.map(
                    (factor) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: factor.isPositive
                                  ? FzColors.success
                                  : factor.isNegative
                                  ? FzColors.danger
                                  : muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  factor.factor,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                if (factor.description.isNotEmpty)
                                  Text(
                                    factor.description,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Narrative
          if (analysis.analysisNarrative != null &&
              analysis.analysisNarrative!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                analysis.analysisNarrative!,
                style: TextStyle(fontSize: 13, color: textColor, height: 1.5),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
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
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return false;
  }
}
