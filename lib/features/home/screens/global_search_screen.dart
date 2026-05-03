import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/hospitality/venue_model.dart';
import '../../../models/platform/search_result_model.dart';
import '../../../providers/search_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../ordering/providers/venue_discovery_provider.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  var _filter = _SearchFilter.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider(_query));
    final venueAsync = ref.watch(venueSearchProvider(_query));
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          children: [
            FzBackHeader(
              title: 'Search',
              subtitle: 'Bars, pools, matches, teams',
              onClose: () => context.go('/home'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search FANZONE',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(LucideIcons.x),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == _SearchFilter.all,
                    onTap: () => setState(() => _filter = _SearchFilter.all),
                  ),
                  _FilterChip(
                    label: 'Bars',
                    selected: _filter == _SearchFilter.bars,
                    onTap: () => setState(() => _filter = _SearchFilter.bars),
                  ),
                  _FilterChip(
                    label: 'Teams',
                    selected: _filter == _SearchFilter.teams,
                    onTap: () => setState(() => _filter = _SearchFilter.teams),
                  ),
                  _FilterChip(
                    label: 'Pools',
                    selected: _filter == _SearchFilter.pools,
                    onTap: () => setState(() => _filter = _SearchFilter.pools),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (!hasQuery) ...[
              const FzSectionHeader(title: 'Recent'),
              const SizedBox(height: 10),
              const _StaticSearchItem(
                icon: LucideIcons.mapPin,
                title: 'Browse sports bars',
                subtitle: 'Open venue discovery',
                route: '/venues',
              ),
              const SizedBox(height: 10),
              const _StaticSearchItem(
                icon: LucideIcons.trophy,
                title: 'Arena pools',
                subtitle: 'Live and upcoming match pools',
                route: '/pools',
              ),
              const SizedBox(height: 22),
              const FzSectionHeader(title: 'Hot Right Now'),
              const SizedBox(height: 10),
              const _HotCard(),
            ] else ...[
              if (_filter == _SearchFilter.all || _filter == _SearchFilter.bars)
                venueAsync.when(
                  data: (venues) => _VenueResults(venues: venues),
                  loading: () => const _SearchLoading(label: 'Searching bars'),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              if (_filter == _SearchFilter.all ||
                  _filter == _SearchFilter.teams ||
                  _filter == _SearchFilter.pools)
                searchAsync.when(
                  data: (results) =>
                      _CatalogResults(results: results, filter: _filter),
                  loading: () => const _SearchLoading(label: 'Searching'),
                  error: (_, _) => const _StaticSearchItem(
                    icon: LucideIcons.alertCircle,
                    title: 'Search unavailable',
                    subtitle: 'Pull back and try again in a moment.',
                    route: '/home',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SearchFilter { all, bars, teams, pools }

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      child: FzPill(label: label, selected: selected, onTap: onTap),
    );
  }
}

class _VenueResults extends StatelessWidget {
  const _VenueResults({required this.venues});

  final List<VenueModel> venues;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FzSectionHeader(title: 'Bars'),
        const SizedBox(height: 10),
        for (final venue in venues.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SearchResultTile(
              icon: LucideIcons.mapPin,
              title: venue.name,
              subtitle: venue.city ?? venue.countryCode.label,
              onTap: () => context.push('/venue/${venue.id}'),
            ),
          ),
      ],
    );
  }
}

class _CatalogResults extends StatelessWidget {
  const _CatalogResults({required this.results, required this.filter});

  final SearchResults results;
  final _SearchFilter filter;

  @override
  Widget build(BuildContext context) {
    final items = <SearchResultModel>[
      if (filter == _SearchFilter.all || filter == _SearchFilter.pools)
        ...results.competitions,
      if (filter == _SearchFilter.all || filter == _SearchFilter.teams)
        ...results.teams,
      ...results.matches,
    ];

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 28),
        child: Center(
          child: Text(
            'No results yet',
            style: TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FzSectionHeader(title: 'Results'),
        const SizedBox(height: 10),
        for (final result in items.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SearchResultTile(
              icon: _iconFor(result.type),
              title: result.title,
              subtitle: result.subtitle,
              onTap: () => context.push(result.route),
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(SearchResultType type) {
    switch (type) {
      case SearchResultType.competition:
        return LucideIcons.trophy;
      case SearchResultType.team:
        return LucideIcons.shield;
      case SearchResultType.match:
        return LucideIcons.calendar;
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.compact,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: FzColors.accent.withValues(alpha: 0.12),
              borderRadius: FzRadii.buttonRadius,
            ),
            child: Icon(icon, color: FzColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

class _StaticSearchItem extends StatelessWidget {
  const _StaticSearchItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return _SearchResultTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => context.push(route),
    );
  }
}

class _HotCard extends StatelessWidget {
  const _HotCard();

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: () => context.push('/pools'),
      padding: const EdgeInsets.all(18),
      borderRadius: FzRadii.card,
      color: FzColors.accent.withValues(alpha: 0.13),
      borderColor: FzColors.accent.withValues(alpha: 0.35),
      child: Row(
        children: [
          const Icon(LucideIcons.flame, color: FzColors.accent3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Live pools and venue rewards are the fastest way into the Arena.',
              style: FzTypography.display(size: 19, color: FzColors.darkText),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLoading extends StatelessWidget {
  const _SearchLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
