import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/sports/match_model.dart';
import '../../../models/hospitality/venue_match_stake_model.dart';
import '../../../models/auth_and_user/user_prediction_model.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../core/di/gateway_providers.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../providers/venue_stake_provider.dart';

class VenueMatchPoolCard extends ConsumerWidget {
  const VenueMatchPoolCard({
    super.key,
    required this.match,
    this.userPrediction,
  });

  final MatchModel match;
  final UserPredictionModel? userPrediction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueContext = ref.watch(venueContextProvider);
    if (!venueContext.hasVenue) return const SizedBox.shrink();

    final stakeAsync = ref.watch(activeMatchStakeProvider((
      venueId: venueContext.venueId!,
      matchId: match.id,
    )));

    return stakeAsync.when(
      data: (stake) {
        if (stake == null) return const SizedBox.shrink();
        return _PoolCardContent(
          venueName: venueContext.venue!.name,
          stake: stake,
          userPrediction: userPrediction,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PoolCardContent extends ConsumerStatefulWidget {
  const _PoolCardContent({
    required this.venueName,
    required this.stake,
    this.userPrediction,
  });

  final String venueName;
  final VenueMatchStakeModel stake;
  final UserPredictionModel? userPrediction;

  @override
  ConsumerState<_PoolCardContent> createState() => _PoolCardContentState();
}

class _PoolCardContentState extends ConsumerState<_PoolCardContent> {
  bool _submitting = false;

  Future<void> _joinPool() async {
    if (widget.userPrediction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please make a prediction before joining the pool.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Venue Pool'),
        content: Text(
          'Join the ${widget.venueName} pool for ${widget.stake.entryFeeFet} FET? \n\nWinners collect the entire pool to spend at the venue!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: FzColors.accent2),
            child: const Text('Join Pool'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await ref.read(venueStakeGatewayProvider).joinStake(widget.stake.id);
      
      // Refresh state
      ref.invalidate(activeMatchStakeProvider);
      ref.invalidate(walletServiceProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined the venue pool!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join pool: $e'),
          backgroundColor: FzColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
              const Icon(LucideIcons.sparkles, size: 16, color: FzColors.accent2),
              const SizedBox(width: 8),
              Text(
                'VENUE POOL',
                style: FzTypography.metaLabel(color: FzColors.accent2),
              ),
              const Spacer(),
              FzBadge(
                label: '${widget.stake.totalPoolFet} FET POOL',
                variant: FzBadgeVariant.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Join the ${widget.venueName} match pool.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Correct picks share the tokens to spend on orders here.',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _joinPool,
              icon: _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FzColors.darkBg,
                      ),
                    )
                  : const Icon(LucideIcons.ticket, size: 16),
              label: Text(_submitting ? 'JOINING...' : 'JOIN FOR ${widget.stake.entryFeeFet} FET'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FzColors.accent2,
                foregroundColor: FzColors.darkBg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
