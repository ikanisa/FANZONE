import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_config.dart';
import '../../../core/di/gateway_providers.dart';
import '../../../models/match_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../widgets/following_widgets.dart';

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
            _FollowedMatchesTab(favourites: favourites),
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
                  QuickAddSection(
                    query: _query,
                    teamsAsync: teamsAsync,
                    competitionsAsync: competitionsAsync,
                    muted: muted,
                  ),
                  const SizedBox(height: 16),
                ],
                FollowedTeamsSection(
                  favourites: favourites,
                  teamsAsync: teamsAsync,
                  muted: muted,
                ),
                if (AppConfig.enableTeamCommunities) ...[
                  const SizedBox(height: 12),
                  SupportedTeamsSection(teamsAsync: teamsAsync, muted: muted),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/teams'),
                      icon: const Icon(LucideIcons.compass, size: 16),
                      label: const Text('Explore All Teams'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FzColors.accent,
                        side: BorderSide(color: FzColors.accent.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FollowedCompetitionsSection(
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

// ── Followed Matches Tab (kept here — uses getIt which will migrate in Phase 2) ──

final _followedMatchesProvider = StreamProvider.autoDispose<List<MatchModel>>((
  ref,
) {
  return ref.read(matchListingGatewayProvider).watchUpcomingMatches();
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
        final end = DateTime(start.year, start.month, start.day).add(const Duration(days: 8));
        final filtered = allMatches.where((match) {
          final inWindow = !match.date.isBefore(DateTime(start.year, start.month, start.day)) && match.date.isBefore(end);
          if (!inWindow) return false;
          return favourites.isCompetitionFavourite(match.competitionId) ||
              (match.homeTeamId != null && favourites.isTeamFavourite(match.homeTeamId!)) ||
              (match.awayTeamId != null && favourites.isTeamFavourite(match.awayTeamId!));
        }).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        if (filtered.isEmpty) {
          return StateView.empty(
            title: favourites.isEmpty ? 'No teams followed yet' : 'No upcoming matches',
            subtitle: favourites.isEmpty
                ? 'Follow teams and competitions to see their matches here.'
                : 'Your followed teams have no matches in the next 7 days.',
            icon: Icons.calendar_today_rounded,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
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
