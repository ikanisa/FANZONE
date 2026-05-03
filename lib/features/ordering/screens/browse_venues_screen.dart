import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/hospitality/venue_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/venue_context_provider.dart';
import '../providers/venue_discovery_provider.dart';

class BrowseVenuesScreen extends ConsumerStatefulWidget {
  const BrowseVenuesScreen({super.key});

  @override
  ConsumerState<BrowseVenuesScreen> createState() => _BrowseVenuesScreenState();
}

class _BrowseVenuesScreenState extends ConsumerState<BrowseVenuesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venueSearchProvider(_query));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activeVenuesProvider);
            ref.invalidate(venueSearchProvider(_query));
            await ref.read(venueSearchProvider(_query).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              const FzReferenceHeader(title: 'Sports Elite'),
              const SizedBox(height: 24),
              Text(
                'Browse Venues',
                style: FzTypography.display(size: 38, color: FzColors.darkText),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find live sports bars, menus, rewards, and pool-ready rooms near you.',
                style: TextStyle(
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search bars, cities, venues',
                  prefixIcon: const Icon(LucideIcons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
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
                    FzPill(
                      label: 'Near Me',
                      icon: LucideIcons.navigation,
                      selected: true,
                      onTap: () => context.push('/venues/location'),
                    ),
                    const SizedBox(width: 8),
                    const FzPill(label: 'Open Now', icon: LucideIcons.clock),
                    const SizedBox(width: 8),
                    const FzPill(label: 'Live Match', icon: LucideIcons.tv),
                    const SizedBox(width: 8),
                    const FzPill(label: 'FET Rewards', icon: LucideIcons.coins),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              venuesAsync.when(
                data: (venues) {
                  if (venues.isEmpty) {
                    return FzEmptyState(
                      title: 'No venues found',
                      description:
                          'Try another search or open location access to discover FANZONE bars.',
                      icon: const Icon(LucideIcons.mapPin),
                      actionLabel: 'Use location',
                      onAction: () => context.push('/venues/location'),
                    );
                  }

                  return Column(
                    children: [
                      for (final venue in venues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _VenueDiscoveryCard(
                            venue: venue,
                            onTap: () => context.push('/venue/${venue.id}'),
                            onOrder: () async {
                              await ref
                                  .read(venueContextProvider.notifier)
                                  .setVenueById(venue.id);
                              if (context.mounted) context.go('/bar');
                            },
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => StateView.error(
                  title: 'Could not load venues',
                  subtitle: error.toString(),
                  onRetry: () => ref.invalidate(venueSearchProvider(_query)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VenueDiscoveryCard extends StatelessWidget {
  const _VenueDiscoveryCard({
    required this.venue,
    required this.onTap,
    required this.onOrder,
  });

  final VenueModel venue;
  final VoidCallback onTap;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              FzImageSurface(
                imageUrl: venue.coverUrl,
                icon: LucideIcons.utensils,
                height: 150,
              ),
              Positioned(
                left: 12,
                top: 12,
                child: FzPill(
                  label: venue.isOpen ? 'Open Now' : 'Venue',
                  icon: venue.isOpen ? LucideIcons.zap : LucideIcons.mapPin,
                  color: venue.isOpen ? FzColors.success : FzColors.accent,
                  selected: true,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (venue.rating != null) ...[
                      const Icon(
                        LucideIcons.star,
                        size: 15,
                        color: FzColors.accent3,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        venue.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    venue.city,
                    venue.venueType.label,
                    venue.primaryCategory,
                  ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: FzMetricTile(
                        label: 'Rewards',
                        value: 'FET',
                        icon: LucideIcons.coins,
                        color: FzColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOrder,
                        icon: const Icon(LucideIcons.utensils, size: 16),
                        label: const Text('Order'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
