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

class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailByIdProvider(venueId));

    return Scaffold(
      body: SafeArea(
        child: venueAsync.when(
          data: (venue) {
            if (venue == null) {
              return FzEmptyState(
                title: 'Venue not found',
                description: 'Choose another.',
                icon: const Icon(LucideIcons.mapPin),
                actionLabel: 'Bars',
                onAction: () => context.go('/venues'),
              );
            }
            return _VenueDetailContent(venue: venue);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StateView.error(
            title: 'Could not load venue',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(venueDetailByIdProvider(venueId)),
          ),
        ),
      ),
    );
  }
}

class _VenueDetailContent extends ConsumerWidget {
  const _VenueDetailContent({required this.venue});

  final VenueModel venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
      children: [
        FzBackHeader(
          title: 'Bar',
          subtitle: venue.city ?? venue.countryCode.label,
          onClose: () => context.go('/venues'),
        ),
        const SizedBox(height: 18),
        Stack(
          children: [
            FzImageSurface(
              imageUrl: venue.coverUrl,
              icon: LucideIcons.utensils,
              height: 230,
            ),
            Positioned(
              left: 14,
              top: 14,
              child: FzPill(
                label: venue.isOpen ? 'Live' : 'Bar',
                icon: venue.isOpen ? LucideIcons.zap : LucideIcons.mapPin,
                color: venue.isOpen ? FzColors.success : FzColors.accent,
                selected: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          venue.name,
          style: FzTypography.display(size: 38, color: FzColors.darkText),
        ),
        const SizedBox(height: 8),
        Text(
          venue.city ?? venue.countryCode.label,
          style: const TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        FzMetricTile(
          label: 'Type',
          value: venue.venueType.label,
          icon: LucideIcons.store,
        ),
        const SizedBox(height: 12),
        FzCard(
          padding: const EdgeInsets.all(16),
          borderRadius: FzRadii.card,
          child: Column(
            children: [
              _VenueInfoRow(
                icon: LucideIcons.mapPin,
                label: 'Address',
                value: venue.fullAddress.isEmpty
                    ? venue.city ?? venue.countryCode.label
                    : venue.fullAddress,
              ),
              const Divider(height: 24),
              _VenueInfoRow(
                icon: LucideIcons.clock,
                label: 'Status',
                value: venue.isOpen ? 'Open' : 'Closed',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () async {
            await ref
                .read(venueContextProvider.notifier)
                .setVenueById(venue.id);
            if (context.mounted) context.go('/bar');
          },
          icon: const Icon(LucideIcons.utensils),
          label: const Text('Menu'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await ref
                .read(venueContextProvider.notifier)
                .setVenueById(venue.id);
            if (context.mounted) context.go('/pools/create');
          },
          icon: const Icon(LucideIcons.trophy),
          label: const Text('Create'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }
}

class _VenueInfoRow extends StatelessWidget {
  const _VenueInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
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
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}
