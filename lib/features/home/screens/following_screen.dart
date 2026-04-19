import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_config.dart';
import '../../../core/di/injection.dart';
import '../../../features/home/data/match_listing_gateway.dart';
import '../../../models/competition_model.dart';
import '../../../models/match_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

class FollowingScreen extends ConsumerStatefulWidget {
  const FollowingScreen({super.key});

  @override
  ConsumerState<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends ConsumerState<FollowingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final favouritesAsync = ref.watch(favouritesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final competitionsAsync = ref.watch(competitionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FOLLOWING',
          style: FzTypography.display(
            size: 28,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Teams'),
            Tab(text: 'Competitions'),
          ],
        ),
      ),
      body: favouritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: StateView.error(
            title: 'Could not load favourites',
            onRetry: () => ref.invalidate(favouritesProvider),
          ),
        ),
        data: (favourites) => TabBarView(
          controller: _tabController,
          children: [
            // Matches tab (P0-F1)
            _FollowedMatchesTab(favourites: favourites),
            // Teams tab
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Add team or competition',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                if (_query.isNotEmpty) ...[
                  _QuickAddSection(
                    query: _query,
                    teamsAsync: teamsAsync,
                    competitionsAsync: competitionsAsync,
                    muted: muted,
                  ),
                  const SizedBox(height: 16),
                ],
                _FollowedTeamsSection(
                  favourites: favourites,
                  teamsAsync: teamsAsync,
                  muted: muted,
                ),
                if (AppConfig.enableTeamCommunities) ...[
                  const SizedBox(height: 12),
                  _SupportedTeamsSection(teamsAsync: teamsAsync, muted: muted),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/clubs/teams'),
                      icon: const Icon(LucideIcons.compass, size: 16),
                      label: const Text('Explore All Teams'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FzColors.accent,
                        side: BorderSide(
                          color: FzColors.accent.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                if (favourites.teamIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: StateView.empty(
                      title: 'No teams followed',
                      subtitle: 'Search to add teams.',
                      icon: Icons.star_outline_rounded,
                    ),
                  ),
                const SizedBox(height: 96),
              ],
            ),
            // Competitions tab
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FollowedCompetitionsSection(
                  favourites: favourites,
                  competitionsAsync: competitionsAsync,
                  muted: muted,
                ),
                if (favourites.competitionIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: StateView.empty(
                      title: 'No competitions followed',
                      subtitle: 'Star competitions from Scores tab.',
                      icon: Icons.star_outline_rounded,
                    ),
                  ),
                const SizedBox(height: 96),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddSection extends ConsumerWidget {
  const _QuickAddSection({
    required this.query,
    required this.teamsAsync,
    required this.competitionsAsync,
    required this.muted,
  });

  final String query;
  final AsyncValue<List<TeamModel>> teamsAsync;
  final AsyncValue<List<CompetitionModel>> competitionsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show loading state when data is still arriving
    if (teamsAsync.isLoading && competitionsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    // Show error if both failed
    if (teamsAsync.hasError && competitionsAsync.hasError) {
      return StateView.error(
        title: 'Could not search',
        onRetry: () {
          ref.invalidate(teamsProvider);
          ref.invalidate(competitionsProvider);
        },
      );
    }

    final lowered = query.toLowerCase();
    final matchingTeams = (teamsAsync.valueOrNull ?? [])
        .where(
          (team) =>
              team.name.toLowerCase().contains(lowered) ||
              (team.shortName?.toLowerCase().contains(lowered) ?? false),
        )
        .take(5)
        .toList();
    final matchingCompetitions = (competitionsAsync.valueOrNull ?? [])
        .where(
          (competition) =>
              competition.name.toLowerCase().contains(lowered) ||
              competition.shortName.toLowerCase().contains(lowered) ||
              competition.country.toLowerCase().contains(lowered),
        )
        .take(5)
        .toList();

    if (matchingTeams.isEmpty && matchingCompetitions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No results for "$query"',
          style: TextStyle(fontSize: 13, color: muted),
        ),
      );
    }

    final favourites =
        ref.watch(favouritesProvider).valueOrNull ?? const FavouritesState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ...matchingTeams.map(
          (team) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FollowableRow(
              title: team.name,
              subtitle: team.country ?? team.shortName ?? '',
              leading: TeamAvatar(name: team.name),
              selected: favourites.isTeamFavourite(team.id),
              onTap: () =>
                  ref.read(favouritesProvider.notifier).toggleTeam(team.id),
            ),
          ),
        ),
        ...matchingCompetitions.map(
          (competition) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FollowableRow(
              title: competition.name,
              subtitle: competition.country,
              leading: const Icon(
                LucideIcons.trophy,
                size: 18,
                color: FzColors.accent,
              ),
              selected: favourites.isCompetitionFavourite(competition.id),
              onTap: () => ref
                  .read(favouritesProvider.notifier)
                  .toggleCompetition(competition.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _FollowedTeamsSection extends ConsumerWidget {
  const _FollowedTeamsSection({
    required this.favourites,
    required this.teamsAsync,
    required this.muted,
  });

  final FavouritesState favourites;
  final AsyncValue<List<TeamModel>> teamsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEAMS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        teamsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (err, st) => StateView.error(
            title: 'Could not load teams',
            onRetry: () => ref.invalidate(teamsProvider),
          ),
          data: (allTeams) {
            final teams =
                allTeams
                    .where((team) => favourites.isTeamFavourite(team.id))
                    .toList()
                  ..sort((left, right) => left.name.compareTo(right.name));

            if (teams.isEmpty) return const SizedBox.shrink();

            return Column(
              children: teams
                  .map(
                    (team) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FollowableRow(
                        title: team.name,
                        subtitle: team.country ?? '',
                        leading: TeamAvatar(name: team.name),
                        selected: true,
                        onTap: () => context.push('/clubs/team/${team.id}'),
                        onTrailingTap: () => ref
                            .read(favouritesProvider.notifier)
                            .toggleTeam(team.id),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FollowedCompetitionsSection extends ConsumerWidget {
  const _FollowedCompetitionsSection({
    required this.favourites,
    required this.competitionsAsync,
    required this.muted,
  });

  final FavouritesState favourites;
  final AsyncValue<List<CompetitionModel>> competitionsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPETITIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        competitionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (err, st) => StateView.error(
            title: 'Could not load competitions',
            onRetry: () => ref.invalidate(competitionsProvider),
          ),
          data: (allComps) {
            final competitions =
                allComps
                    .where(
                      (competition) =>
                          favourites.isCompetitionFavourite(competition.id),
                    )
                    .toList()
                  ..sort((left, right) => left.name.compareTo(right.name));

            if (competitions.isEmpty) return const SizedBox.shrink();

            return Column(
              children: competitions
                  .map(
                    (competition) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FollowableRow(
                        title: competition.name,
                        subtitle: competition.country,
                        leading: const Icon(
                          LucideIcons.trophy,
                          size: 18,
                          color: FzColors.accent,
                        ),
                        selected: true,
                        onTap: () => context.push('/league/${competition.id}'),
                        onTrailingTap: () => ref
                            .read(favouritesProvider.notifier)
                            .toggleCompetition(competition.id),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FollowableRow extends StatelessWidget {
  const _FollowableRow({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.onTrailingTap,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onTrailingTap ?? onTap,
            icon: Icon(
              selected ? Icons.star_rounded : Icons.add_rounded,
              color: selected ? FzColors.amber : FzColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── New: Followed Matches Tab (P0-F1) ──────────────────────────

final _followedMatchesProvider = StreamProvider.autoDispose<List<MatchModel>>((
  ref,
) {
  return getIt<MatchListingGateway>().watchUpcomingMatches();
});

class _FollowedMatchesTab extends ConsumerWidget {
  const _FollowedMatchesTab({required this.favourites});

  final FavouritesState favourites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(_followedMatchesProvider);

    return matchesAsync.when(
      data: (allMatches) {
        final start = DateTime.now();
        final end = DateTime(
          start.year,
          start.month,
          start.day,
        ).add(const Duration(days: 8));
        final filtered = allMatches.where((match) {
          final inWindow =
              !match.date.isBefore(
                DateTime(start.year, start.month, start.day),
              ) &&
              match.date.isBefore(end);

          if (!inWindow) {
            return false;
          }

          return favourites.isCompetitionFavourite(match.competitionId) ||
              (match.homeTeamId != null &&
                  favourites.isTeamFavourite(match.homeTeamId!)) ||
              (match.awayTeamId != null &&
                  favourites.isTeamFavourite(match.awayTeamId!));
        }).toList()..sort((a, b) => a.date.compareTo(b.date));

        if (filtered.isEmpty) {
          return StateView.empty(
            title: favourites.isEmpty
                ? 'No teams followed yet'
                : 'No upcoming matches',
            subtitle: favourites.isEmpty
                ? 'Follow teams and competitions to see their matches here.'
                : 'Your followed teams have no matches in the next 7 days.',
            icon: Icons.calendar_today_rounded,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final match = filtered[index];
            return FzCard(
              padding: EdgeInsets.zero,
              child: MatchListRow(
                match: match,
                onTap: () => context.push('/match/${match.id}'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => StateView.error(
        title: 'Could not load matches',
        onRetry: () => ref.invalidate(_followedMatchesProvider),
      ),
    );
  }
}

// ── Supported Teams Section (team community) ──────────────────────

class _SupportedTeamsSection extends ConsumerWidget {
  const _SupportedTeamsSection({required this.teamsAsync, required this.muted});

  final AsyncValue<List<TeamModel>> teamsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ?? {};

    if (supportedIds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SUPPORTING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FzColors.maltaRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${supportedIds.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FzColors.maltaRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        teamsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Loading supported teams...',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Supported teams are unavailable right now.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          data: (allTeams) {
            final supported =
                allTeams
                    .where((team) => supportedIds.contains(team.id))
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

            if (supported.isEmpty) return const SizedBox.shrink();

            return Column(
              children: supported
                  .map(
                    (team) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FollowableRow(
                        title: team.name,
                        subtitle: team.country ?? '',
                        leading: TeamAvatar(name: team.name),
                        selected: true,
                        onTap: () => context.push('/clubs/team/${team.id}'),
                        onTrailingTap: () => ref
                            .read(supportedTeamsServiceProvider.notifier)
                            .toggleSupport(team.id),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
