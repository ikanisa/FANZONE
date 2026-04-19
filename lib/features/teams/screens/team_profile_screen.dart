import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/match_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/standings_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/team/team_widgets.dart';
import '../../../widgets/team/fet_contribution_sheet.dart';

/// Enhanced team profile page with community features.
///
/// Tabs: Overview | News | Fan Zone | Support Club
class TeamProfileScreen extends ConsumerWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamProvider(teamId));
    final matchesAsync = ref.watch(teamMatchesProvider(teamId));
    final competitionsAsync = ref.watch(competitionsProvider);
    final favourites =
        ref.watch(favouritesProvider).valueOrNull ?? const FavouritesState();

    return teamAsync.when(
      data: (team) {
        if (team == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Team')),
            body: StateView.empty(
              title: 'Team not found',
              subtitle: 'Return to search.',
            ),
          );
        }

        final competitions = (competitionsAsync.valueOrNull ?? [])
            .where((c) => team.competitionIds.contains(c.id))
            .toList();

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(team.shortName ?? team.name),
              actions: [
                IconButton(
                  onPressed: () =>
                      ref.read(favouritesProvider.notifier).toggleTeam(team.id),
                  icon: Icon(
                    favourites.isTeamFavourite(team.id)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: favourites.isTeamFavourite(team.id)
                        ? FzColors.amber
                        : null,
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Premium hero header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TeamHeroHeader(team: team),
                ),

                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'News'),
                    Tab(text: 'Fan Zone'),
                    Tab(text: 'Support Club'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(
                        team: team,
                        matchesAsync: matchesAsync,
                        competitions: competitions,
                        competitionsAsync: competitionsAsync,
                      ),
                      _NewsTab(teamId: teamId),
                      _CommunityTab(teamId: teamId, team: team),
                      _ContributionsTab(team: team),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Team')),
        body: StateView.error(
          title: 'Team unavailable',
          subtitle: 'Try again later.',
          onRetry: () => ref.invalidate(teamProvider(teamId)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Overview Tab — form guide, table position, next/recent matches
// ─────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.team,
    required this.matchesAsync,
    required this.competitions,
    required this.competitionsAsync,
  });

  final TeamModel team;
  final AsyncValue<List<MatchModel>> matchesAsync;
  final List<dynamic> competitions;
  final AsyncValue<List<dynamic>> competitionsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryCompetition = competitions.isNotEmpty
        ? competitions.first
        : null;
    final primaryStandingAsync = primaryCompetition == null
        ? const AsyncValue<List<dynamic>>.data([])
        : ref.watch(
            competitionStandingsProvider(
              CompetitionStandingsFilter(competitionId: primaryCompetition.id),
            ),
          );

    return matchesAsync.when(
      data: (matches) {
        final upcoming = matches.where((m) => m.isUpcoming || m.isLive).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final results = matches.where((m) => m.isFinished).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final List<MatchModel> trimmedUpcoming = upcoming.take(4).toList();
        final List<MatchModel> trimmedResults = results.take(4).toList();
        final facts = <({String label, String value})>[
          (label: 'Country', value: team.country ?? '—'),
          (label: 'Leagues', value: '${team.competitionIds.length}'),
          (label: 'Upcoming', value: '${upcoming.length}'),
          (label: 'Fans', value: '${team.fanCount}'),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Form guide
            if (results.isNotEmpty) ...[
              _FormGuide(team: team, results: results),
              const SizedBox(height: 16),
            ],

            MatchFactsGrid(facts: facts),

            // League table position
            if (primaryCompetition != null) ...[
              const SizedBox(height: 16),
              primaryStandingAsync.when(
                data: (rows) {
                  final matchingRows = rows.cast().where(
                    (item) => item.teamId == team.id,
                  );
                  final row = matchingRows.isEmpty ? null : matchingRows.first;
                  if (row == null) return const SizedBox.shrink();
                  return FzCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricCell(
                            label: 'Pos',
                            value: '${row.position}',
                          ),
                        ),
                        Expanded(
                          child: _MetricCell(
                            label: 'P',
                            value: '${row.played}',
                          ),
                        ),
                        Expanded(
                          child: _MetricCell(
                            label: 'GD',
                            value: '${row.goalDifference}',
                          ),
                        ),
                        Expanded(
                          child: _MetricCell(
                            label: 'Pts',
                            value: '${row.points}',
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const _InlineStatusCard(
                  message: 'Table position is unavailable right now.',
                ),
              ),
            ],

            // Upcoming
            if (trimmedUpcoming.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Next',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              MatchListCard(
                matches: trimmedUpcoming,
                onTapMatch: (match) => context.push('/match/${match.id}'),
              ),
            ],

            // Recent results
            if (trimmedResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Recent',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              MatchListCard(
                matches: trimmedResults,
                onTapMatch: (match) => context.push('/match/${match.id}'),
              ),
            ],

            // Competition chips
            if (competitions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: competitions
                    .map(
                      (c) => InlineActionChip(
                        label: c.shortName,
                        onTap: () => context.push('/league/${c.id}'),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 32),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => StateView.error(title: 'Data unavailable'),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// News Tab — AI-curated team news
// ─────────────────────────────────────────────────────────────

class _NewsTab extends ConsumerWidget {
  const _NewsTab({required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(teamNewsProvider(teamId));

    return newsAsync.when(
      data: (news) {
        if (news.isEmpty) {
          return StateView.empty(
            title: 'No news yet',
            subtitle: 'Team news will appear here once published.',
            icon: Icons.newspaper_rounded,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: news.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => TeamNewsCard(
            news: news[index],
            index: index,
            onTap: () =>
                context.push('/clubs/team/$teamId/news/${news[index].id}'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => StateView.error(
        title: 'News unavailable',
        onRetry: () => ref.invalidate(teamNewsProvider(teamId)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Community Tab — anonymous fan registry + stats
// ─────────────────────────────────────────────────────────────

class _CommunityTab extends ConsumerWidget {
  const _CommunityTab({required this.teamId, required this.team});
  final String teamId;
  final TeamModel team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teamCommunityStatsProvider(teamId));
    final fansAsync = ref.watch(teamAnonymousFansProvider(teamId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Community stats card
        statsAsync.when(
          data: (stats) {
            if (stats == null) return const SizedBox.shrink();
            return CommunityStatsCard(stats: stats);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const _InlineStatusCard(
            message: 'Community stats are temporarily unavailable.',
          ),
        ),

        const SizedBox(height: 16),
        Text(
          'FAN REGISTRY',
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(height: 4),
        Text(
          'Anonymous identifiers only — personal data is never shown.',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? FzColors.darkMuted
                : FzColors.lightMuted,
          ),
        ),
        const SizedBox(height: 12),

        // Anonymous fans list
        fansAsync.when(
          data: (fans) {
            if (fans.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: StateView.empty(
                  title: 'No supporters yet',
                  subtitle: 'Be the first to support ${team.name}!',
                  icon: Icons.people_outline_rounded,
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < fans.length; i++) ...[
                  AnonymousFanBadge(
                    fanId: fans[i].anonymousFanId,
                    joinedAt: fans[i].joinedAt,
                    index: i,
                  ),
                  if (i < fans.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => StateView.error(
            title: 'Could not load fans',
            onRetry: () => ref.invalidate(teamAnonymousFansProvider(teamId)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Contributions Tab — CTAs + history
// ─────────────────────────────────────────────────────────────

class _ContributionsTab extends ConsumerWidget {
  const _ContributionsTab({required this.team});
  final TeamModel team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(teamContributionHistoryProvider(team.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contribution CTAs
        ContributionCTA(
          team: team,
          onFetTap: () async {
            final success = await FETContributionSheet.show(context, team);
            if (success == true) {
              ref.invalidate(teamContributionHistoryProvider(team.id));
              ref.invalidate(teamCommunityStatsProvider(team.id));
            }
          },
          onFiatTap: () {
            final link = team.fiatContributionLink;
            if (link == null || link.isEmpty) return;
            final uri = Uri.tryParse(link);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),

        if (!team.fetContributionsEnabled && !team.fiatContributionsEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: StateView.empty(
              title: 'Contributions not enabled',
              subtitle: 'This team has not yet enabled contributions.',
              icon: Icons.lock_outline_rounded,
            ),
          ),

        const SizedBox(height: 16),

        // Contribution history
        historyAsync.when(
          data: (contributions) {
            if (contributions.isEmpty) return const SizedBox.shrink();
            return TeamContributionSummaryCard(contributions: contributions);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const _InlineStatusCard(
            message: 'Contribution history could not be loaded.',
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _InlineStatusCard extends StatelessWidget {
  const _InlineStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: muted, height: 1.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────

class _FormGuide extends StatelessWidget {
  const _FormGuide({required this.team, required this.results});
  final TeamModel team;
  final List results;

  @override
  Widget build(BuildContext context) {
    final form = results
        .take(5)
        .map((m) {
          if (m.ftHome == m.ftAway) return 'D';
          final isHome = m.homeTeamId == team.id;
          if (isHome) {
            return (m.ftHome ?? 0) > (m.ftAway ?? 0) ? 'W' : 'L';
          }
          return (m.ftAway ?? 0) > (m.ftHome ?? 0) ? 'W' : 'L';
        })
        .toList()
        .reversed
        .toList();

    return Row(
      children: [
        Text(
          'Form',
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(width: 16),
        ...form.map(
          (f) => Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: f == 'W'
                  ? FzColors.success
                  : (f == 'L' ? FzColors.maltaRed : FzColors.amber),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                f,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
