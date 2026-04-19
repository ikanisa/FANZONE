import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/competition_model.dart';
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

class TeamHubScreen extends ConsumerWidget {
  const TeamHubScreen({super.key, required this.teamId});

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
            .where(
              (competition) => team.competitionIds.contains(competition.id),
            )
            .toList();
        final primaryCompetition = competitions.isNotEmpty
            ? competitions.first
            : null;
        final primaryStandingAsync = primaryCompetition == null
            ? const AsyncValue<List<dynamic>>.data([])
            : ref.watch(
                competitionStandingsProvider(
                  CompetitionStandingsFilter(
                    competitionId: primaryCompetition.id,
                  ),
                ),
              );

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _TeamHeader(team: team, competitions: competitions),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Fixtures'),
                    Tab(text: 'Results'),
                    Tab(text: 'Competitions'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TeamOverviewTab(
                        team: team,
                        matchesAsync: matchesAsync,
                        primaryCompetition: primaryCompetition,
                        primaryStandingAsync: primaryStandingAsync,
                      ),
                      _TeamFixturesTab(matchesAsync: matchesAsync),
                      _TeamResultsTab(matchesAsync: matchesAsync),
                      _TeamCompetitionsTab(competitions: competitions),
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

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team, required this.competitions});

  final TeamModel team;
  final List<CompetitionModel> competitions;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TeamAvatar(name: team.name, size: 58),
          const SizedBox(height: 12),
          Text(
            team.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if ((team.country ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              team.country!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkMuted
                    : FzColors.lightMuted,
              ),
            ),
          ],
          if (competitions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: competitions
                  .map(
                    (competition) =>
                        InlineActionChip(label: competition.shortName),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamOverviewTab extends StatelessWidget {
  const _TeamOverviewTab({
    required this.team,
    required this.matchesAsync,
    required this.primaryCompetition,
    required this.primaryStandingAsync,
  });

  final TeamModel team;
  final AsyncValue<List<MatchModel>> matchesAsync;
  final CompetitionModel? primaryCompetition;
  final AsyncValue<List<dynamic>> primaryStandingAsync;

  @override
  Widget build(BuildContext context) {
    return matchesAsync.when(
      data: (matches) {
        final upcoming =
            matches.where((match) => match.isUpcoming || match.isLive).toList()
              ..sort((left, right) => left.date.compareTo(right.date));
        final results = matches.where((match) => match.isFinished).toList()
          ..sort((left, right) => right.date.compareTo(left.date));
        final trimmedUpcoming = upcoming.take(4).toList();
        final trimmedResults = results.take(4).toList();
        final facts = <({String label, String value})>[
          (label: 'Country', value: team.country ?? '—'),
          (label: 'Competitions', value: '${team.competitionIds.length}'),
          (label: 'Upcoming', value: '${upcoming.length}'),
          (label: 'Results', value: '${results.length}'),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (results.isNotEmpty) ...[
              _TeamFormGuide(team: team, results: results),
              const SizedBox(height: 16),
            ],
            MatchFactsGrid(facts: facts),
            if (primaryCompetition != null) ...[
              const SizedBox(height: 16),
              Text(
                'Table',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              primaryStandingAsync.when(
                data: (rows) {
                  final matchingRows = rows.cast().where(
                    (item) => item.teamId == team.id,
                  );
                  final row = matchingRows.isEmpty ? null : matchingRows.first;
                  if (row == null) {
                    return const SizedBox.shrink();
                  }
                  return FzCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Pos',
                            value: '${row.position}',
                          ),
                        ),
                        Expanded(
                          child: _Metric(label: 'P', value: '${row.played}'),
                        ),
                        Expanded(
                          child: _Metric(
                            label: 'GD',
                            value: '${row.goalDifference}',
                          ),
                        ),
                        Expanded(
                          child: _Metric(label: 'Pts', value: '${row.points}'),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
            ],
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
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => StateView.error(
        title: 'Team fixtures unavailable',
        subtitle: 'Try again later.',
      ),
    );
  }
}

class _TeamFixturesTab extends StatelessWidget {
  const _TeamFixturesTab({required this.matchesAsync});

  final AsyncValue<List<MatchModel>> matchesAsync;

  @override
  Widget build(BuildContext context) {
    return matchesAsync.when(
      data: (allMatches) {
        final matches = allMatches.where((m) => m.isUpcoming || m.isLive).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        if (matches.isEmpty) {
          return StateView.empty(
            title: 'No fixtures',
            subtitle: 'No matches available.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MatchListCard(
              matches: matches,
              onTapMatch: (match) => context.push('/match/${match.id}'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => StateView.error(
        title: 'Team fixtures unavailable',
        subtitle: 'Try again later.',
      ),
    );
  }
}

class _TeamCompetitionsTab extends StatelessWidget {
  const _TeamCompetitionsTab({required this.competitions});

  final List<CompetitionModel> competitions;

  @override
  Widget build(BuildContext context) {
    if (competitions.isEmpty) {
      return StateView.empty(
        title: 'No competitions',
        subtitle: 'No competition links available.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: competitions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final competition = competitions[index];
        return FzCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: () => context.push('/league/${competition.id}'),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: FzColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        competition.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        competition.country,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? FzColors.darkMuted
                              : FzColors.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
            color: Theme.of(context).brightness == Brightness.dark
                ? FzColors.darkMuted
                : FzColors.lightMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TeamResultsTab extends StatelessWidget {
  const _TeamResultsTab({required this.matchesAsync});

  final AsyncValue<List<MatchModel>> matchesAsync;

  @override
  Widget build(BuildContext context) {
    return matchesAsync.when(
      data: (allMatches) {
        final results = allMatches.where((m) => m.isFinished).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        if (results.isEmpty) {
          return StateView.empty(
            title: 'No results',
            subtitle: 'No finished matches available.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MatchListCard(
              matches: results,
              onTapMatch: (match) => context.push('/match/${match.id}'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => StateView.error(
        title: 'Results unavailable',
        subtitle: 'Try again later.',
      ),
    );
  }
}

class _TeamFormGuide extends StatelessWidget {
  const _TeamFormGuide({required this.team, required this.results});
  
  final TeamModel team;
  final List<MatchModel> results;
  
  @override
  Widget build(BuildContext context) {
    final form = results.take(5).map((m) {
      if (m.ftHome == m.ftAway) return 'D';
      final isHome = m.homeTeamId == team.id;
      if (isHome) {
        return (m.ftHome ?? 0) > (m.ftAway ?? 0) ? 'W' : 'L';
      }
      return (m.ftAway ?? 0) > (m.ftHome ?? 0) ? 'W' : 'L';
    }).toList().reversed.toList();
    
    return Row(
      children: [
        Text(
          'Form',
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(width: 16),
        ...form.map((f) => Container(
          width: 24, height: 24,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: f == 'W' ? FzColors.success : (f == 'L' ? FzColors.maltaRed : FzColors.amber),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              f,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            )
          ),
        )),
      ],
    );
  }
}
