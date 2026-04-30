import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_badge.dart';
import '../providers/venue_stake_provider.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../../../models/hospitality/venue_match_stake_model.dart';

class VenueGamificationScreen extends ConsumerWidget {
  const VenueGamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueContext = ref.watch(venueContextProvider);
    if (!venueContext.hasVenue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Venue Gamification')),
        body: StateView.empty(
          title: 'No venue active',
          subtitle: 'Please select a venue from the dashboard.',
          icon: LucideIcons.building,
        ),
      );
    }

    final stakesAsync = ref.watch(venueStakesProvider(venueContext.venueId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamification'),
        actions: [
          IconButton(
            onPressed: () => context.push('/venue-dashboard/stakes/create'),
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
      body: stakesAsync.when(
        data: (stakes) {
          if (stakes.isEmpty) {
            return StateView.empty(
              title: 'No stakes created',
              subtitle: 'Start by creating a stake for an upcoming match.',
              icon: LucideIcons.target,
              action: () => context.push('/venue-dashboard/stakes/create'),
              actionLabel: 'Create Stake',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stakes.length,
            itemBuilder: (context, index) {
              final stake = stakes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StakeListItem(stake: stake),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StateView.error(
          title: 'Failed to load stakes',
          subtitle: e.toString(),
        ),
      ),
    );
  }
}

class _StakeListItem extends StatelessWidget {
  const _StakeListItem({required this.stake});

  final VenueMatchStakeModel stake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final mutedColor = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FzBadge(
                label: stake.status.name.toUpperCase(),
                variant: _variantForStatus(stake.status),
              ),
              const Spacer(),
              Text(
                'Fee: ${stake.entryFeeFet} FET',
                style: FzTypography.metaLabel(color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Match ID: ${stake.matchId}', // In a real app, we'd fetch match details
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(LucideIcons.users, size: 14, color: mutedColor),
              const SizedBox(width: 6),
              Text(
                'Total Pool: ${stake.totalPoolFet} FET',
                style: TextStyle(fontSize: 13, color: mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  FzBadgeVariant _variantForStatus(VenueStakeStatus status) {
    switch (status) {
      case VenueStakeStatus.open:
        return FzBadgeVariant.success;
      case VenueStakeStatus.settled:
        return FzBadgeVariant.ghost;
      case VenueStakeStatus.cancelled:
        return FzBadgeVariant.danger;
    }
  }
}
