import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/match_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/standings_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/match/standings_table.dart';
import '../../../widgets/common/fz_shimmer.dart';

class LeagueHubScreen extends ConsumerWidget {
  const LeagueHubScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(competitionProvider(leagueId));
    final standingsAsync = ref.watch(
      competitionStandingsProvider(
        CompetitionStandingsFilter(competitionId: leagueId),
      ),
    );
    final matchesAsync = ref.watch(competitionMatchesProvider(leagueId));
    final teamsAsync = ref.watch(teamsByCompetitionProvider(leagueId));
    final favourites =
        ref.watch(favouritesProvider).valueOrNull ?? const FavouritesState();

    return competitionAsync.when(
      data: (competition) {
        if (competition == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Competition')),
            body: StateView.empty(
              title: 'Competition not found',
              subtitle: 'Return to fixtures.',
            ),
          );
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(competition.shortName),
              actions: [
                IconButton(
                  onPressed: () => ref
                      .read(favouritesProvider.notifier)
                      .toggleCompetition(competition.id),
                  icon: Icon(
                    favourites.isCompetitionFavourite(competition.id)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: favourites.isCompetitionFavourite(competition.id)
                        ? FzColors.amber
                        : null,
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: FzCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          competition.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InlineActionChip(label: competition.country),
                            if (competition.teamCount != null)
                              InlineActionChip(
                                label: '${competition.teamCount} teams',
                              ),
                            if (competition.seasons.isNotEmpty)
                              InlineActionChip(label: competition.seasons.last),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Table'),
                    Tab(text: 'Fixtures'),
                    Tab(text: 'Results'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Teams'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _LeagueTableTab(standingsAsync: standingsAsync),
                      _LeagueFixturesTab(matchesAsync: matchesAsync),
                      _LeagueResultsTab(matchesAsync: matchesAsync),
                      _LeagueStatsTab(
                        matchesAsync: matchesAsync,
                        teamsAsync: teamsAsync,
                      ),
                      _LeagueTeamsTab(teamsAsync: teamsAsync),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: ScoresPageSkeleton()),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Competition')),
        body: StateView.error(
          title: 'Competition unavailable',
          subtitle: 'Try again later.',
          onRetry: () => ref.invalidate(competitionProvider(leagueId)),
        ),
      ),
    );
  }
}

class _LeagueTableTab extends StatelessWidget {
  const _LeagueTableTab({required this.standingsAsync});

  final AsyncValue<List<dynamic>> standingsAsync;

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
              onTapTeam: (teamId) => context.push('/team/$teamId'),
            );
          },
          loading: () => const FzCard(
            padding: EdgeInsets.all(20),
            child: ScoresPageSkeleton(),
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

class _LeagueFixturesTab extends StatelessWidget {
  const _LeagueFixturesTab({required this.matchesAsync});

  final AsyncValue<List<MatchModel>> matchesAsync;

  @override
  Widget build(BuildContext context) {
    return matchesAsync.when(
      data: (matches) {
        final live = matches.where((m) => m.isLive).toList();
        final upcoming = matches.where((m) => m.isUpcoming).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final combined = [...live, ...upcoming];

        if (combined.isEmpty) {
          return StateView.empty(
            title: 'No upcoming fixtures',
            subtitle: 'All matches have been played.',
            icon: Icons.calendar_today_rounded,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (live.isNotEmpty) ...[
              Text(
                'Live',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              MatchListCard(
                matches: live,
                onTapMatch: (match) => context.push('/match/${match.id}'),
              ),
              const SizedBox(height: 16),
            ],
            if (upcoming.isNotEmpty) ...[
              Text(
                'Upcoming',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              MatchListCard(
                matches: upcoming.take(20).toList(),
                onTapMatch: (match) => context.push('/match/${match.id}'),
              ),
            ],
          ],
        );
      },
      loading: () => const ScoresPageSkeleton(),
      error: (error, stackTrace) => StateView.error(
        title: 'Fixtures unavailable',
        subtitle: 'Try again later.',
      ),
    );
  }
}

class _LeagueResultsTab extends StatelessWidget {
  const _LeagueResultsTab({required this.matchesAsync});

  final AsyncValue<List<MatchModel>> matchesAsync;

  @override
  Widget build(BuildContext context) {
    return matchesAsync.when(
      data: (matches) {
        final results = matches.where((m) => m.isFinished).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        if (results.isEmpty) {
          return StateView.empty(
            title: 'No results yet',
            subtitle: 'Season matches have not started.',
            icon: Icons.scoreboard_outlined,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MatchListCard(
              matches: results.take(20).toList(),
              onTapMatch: (match) => context.push('/match/${match.id}'),
            ),
          ],
        );
      },
      loading: () => const ScoresPageSkeleton(),
      error: (error, stackTrace) => StateView.error(
        title: 'Results unavailable',
        subtitle: 'Try again later.',
      ),
    );
  }
}

class _LeagueTeamsTab extends StatelessWidget {
  const _LeagueTeamsTab({required this.teamsAsync});

  final AsyncValue<List<dynamic>> teamsAsync;

  @override
  Widget build(BuildContext context) {
    return teamsAsync.when(
      data: (teams) {
        if (teams.isEmpty) {
          return StateView.empty(
            title: 'No teams',
            subtitle: 'No teams available.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final team = teams[index];
            return FzCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: InkWell(
                onTap: () => context.push('/team/${team.id}'),
                child: Row(
                  children: [
                    TeamAvatar(name: team.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        team.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const ScoresPageSkeleton(),
      error: (error, stackTrace) => StateView.error(
        title: 'Teams unavailable',
        subtitle: 'Try again later.',
      ),
    );
  }
}

class _LeagueStatsTab extends StatelessWidget {
  const _LeagueStatsTab({required this.matchesAsync, required this.teamsAsync});

  final AsyncValue<List<MatchModel>> matchesAsync;
  final AsyncValue<List<TeamModel>> teamsAsync;

  @override
  Widget build(BuildContext context) {
    return matchesAsync.when(
      data: (matches) {
        final teams = teamsAsync.valueOrNull ?? const <TeamModel>[];
        final finished = matches.where((m) => m.isFinished).toList();
        final live = matches.where((m) => m.isLive).toList();
        final upcoming = matches.where((m) => m.isUpcoming).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final totalGoals = finished.fold<int>(
          0,
          (sum, match) => sum + (match.ftHome ?? 0) + (match.ftAway ?? 0),
        );
        final averageGoals = finished.isEmpty
            ? '—'
            : (totalGoals / finished.length).toStringAsFixed(1);
        final biggestMatch = finished.isEmpty
            ? null
            : (finished.toList()..sort(
                    (a, b) => ((b.ftHome ?? 0) + (b.ftAway ?? 0)).compareTo(
                      (a.ftHome ?? 0) + (a.ftAway ?? 0),
                    ),
                  ))
                  .first;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Competition Snapshot',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _LeagueMetricCard(label: 'Teams', value: '${teams.length}'),
                _LeagueMetricCard(label: 'Played', value: '${finished.length}'),
                _LeagueMetricCard(label: 'Live', value: '${live.length}'),
                _LeagueMetricCard(label: 'Avg Goals', value: averageGoals),
              ],
            ),
            const SizedBox(height: 16),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Key moments',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _LeagueInsightRow(
                    icon: Icons.sports_soccer_rounded,
                    label: 'Goals scored',
                    value:
                        '$totalGoals across ${finished.length} finished matches',
                  ),
                  const SizedBox(height: 12),
                  _LeagueInsightRow(
                    icon: Icons.live_tv_rounded,
                    label: 'Live now',
                    value: live.isEmpty
                        ? 'No matches are live in this competition right now'
                        : '${live.length} match${live.length == 1 ? '' : 'es'} currently live',
                  ),
                  const SizedBox(height: 12),
                  _LeagueInsightRow(
                    icon: Icons.schedule_rounded,
                    label: 'Next kickoff',
                    value: upcoming.isEmpty
                        ? 'No upcoming fixtures scheduled'
                        : '${upcoming.first.homeTeam} vs ${upcoming.first.awayTeam}',
                  ),
                ],
              ),
            ),
            if (biggestMatch != null) ...[
              const SizedBox(height: 16),
              FzCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Highest-scoring result',
                      style: FzTypography.sectionLabel(
                        Theme.of(context).brightness,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${biggestMatch.homeTeam} ${biggestMatch.ftHome ?? 0}–${biggestMatch.ftAway ?? 0} ${biggestMatch.awayTeam}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const ScoresPageSkeleton(),
      error: (_, _) => StateView.empty(
        title: 'Competition stats unavailable',
        subtitle: 'Try again later.',
        icon: Icons.bar_chart_rounded,
      ),
    );
  }
}

class _LeagueMetricCard extends StatelessWidget {
  const _LeagueMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: FzCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 8),
            Text(value, style: FzTypography.scoreLarge(color: FzColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _LeagueInsightRow extends StatelessWidget {
  const _LeagueInsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: FzColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      ],
    );
  }
}
