import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/market/launch_market.dart';
import '../../../models/team_model.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/team/team_widgets.dart';

/// Teams discovery screen — browse, search, and support teams.
class TeamsDiscoveryScreen extends ConsumerStatefulWidget {
  const TeamsDiscoveryScreen({super.key});

  @override
  ConsumerState<TeamsDiscoveryScreen> createState() =>
      _TeamsDiscoveryScreenState();
}

class _TeamsDiscoveryScreenState extends ConsumerState<TeamsDiscoveryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _regionFilter = 'for_you';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final teamsAsync = ref.watch(teamsProvider);
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ?? {};
    final preferredRegion = ref.watch(primaryMarketRegionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CLUB DISCOVERY',
          style: FzTypography.display(
            size: 28,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
      ),
      body: teamsAsync.when(
        data: (allTeams) {
          final activeRegion = _regionFilter == 'for_you'
              ? preferredRegion
              : _regionFilter;

          // Filter by search
          final lowered = _query.toLowerCase();
          final filtered = _query.isEmpty
              ? allTeams
              : allTeams.where((t) {
                  return t.name.toLowerCase().contains(lowered) ||
                      (t.shortName?.toLowerCase().contains(lowered) ?? false) ||
                      (t.country?.toLowerCase().contains(lowered) ?? false) ||
                      (t.leagueName?.toLowerCase().contains(lowered) ?? false);
                }).toList();

          final regionFiltered = activeRegion == 'global'
              ? filtered
              : filtered
                    .where((team) => _matchesRegion(team, activeRegion))
                    .toList();

          // Separate supported teams to top
          final supported = <TeamModel>[];
          final others = <TeamModel>[];
          for (final team in regionFiltered) {
            if (supportedIds.contains(team.id)) {
              supported.add(team);
            } else {
              others.add(team);
            }
          }

          // Featured teams first, then others
          final featured = others.where((t) => t.isFeatured).toList();
          final remaining = others.where((t) => !t.isFeatured).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FzCard(
                    padding: const EdgeInsets.all(16),
                    borderColor: FzColors.accent.withValues(alpha: 0.22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DISCOVERY FOR ${launchRegionLabel(activeRegion).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FzColors.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'FANZONE now launches globally. Browse clubs with ${launchRegionLabel(activeRegion).toLowerCase()} weighted first while keeping the wider football map available.',
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search clubs and teams...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _RegionFilterChip(
                        label: 'For You',
                        selected: _regionFilter == 'for_you',
                        onTap: () => setState(() => _regionFilter = 'for_you'),
                      ),
                      _RegionFilterChip(
                        label: 'Global',
                        selected: _regionFilter == 'global',
                        onTap: () => setState(() => _regionFilter = 'global'),
                      ),
                      _RegionFilterChip(
                        label: 'Africa',
                        selected: _regionFilter == 'africa',
                        onTap: () => setState(() => _regionFilter = 'africa'),
                      ),
                      _RegionFilterChip(
                        label: 'Europe',
                        selected: _regionFilter == 'europe',
                        onTap: () => setState(() => _regionFilter = 'europe'),
                      ),
                      _RegionFilterChip(
                        label: 'North America',
                        selected: _regionFilter == 'north_america',
                        onTap: () =>
                            setState(() => _regionFilter = 'north_america'),
                      ),
                    ],
                  ),
                ),
              ),

              // Supported teams section
              if (supported.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'YOUR TEAMS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: supported.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => TeamCard(
                      team: supported[index],
                      index: index,
                      onTap: () =>
                          context.push('/team/${supported[index].id}'),
                    ),
                  ),
                ),
              ],

              // Featured teams section
              if (featured.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'FEATURED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: featured.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => TeamCard(
                      team: featured[index],
                      index: index,
                      onTap: () =>
                          context.push('/team/${featured[index].id}'),
                    ),
                  ),
                ),
              ],

              // All teams section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'ALL TEAMS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              if (remaining.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: StateView.empty(
                      title: _query.isEmpty
                          ? 'No teams available'
                          : 'No results for "$_query"',
                      subtitle: 'Try another region filter or search term.',
                      icon: Icons.sports_soccer_rounded,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: remaining.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => TeamCard(
                      team: remaining[index],
                      index: index,
                      onTap: () =>
                          context.push('/team/${remaining[index].id}'),
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => StateView.error(
          title: 'Could not load teams',
          onRetry: () => ref.invalidate(teamsProvider),
        ),
      ),
    );
  }
}

bool _matchesRegion(TeamModel team, String region) {
  final teamRegion = regionFromCountryName(team.country);
  if (teamRegion == null) return region == 'global';
  return regionKeyMatches(teamRegion, region);
}

class _RegionFilterChip extends StatelessWidget {
  const _RegionFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
