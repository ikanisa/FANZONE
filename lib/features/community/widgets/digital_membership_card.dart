import 'package:flutter/material.dart';

import '../../../models/team_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_wordmark.dart';
import '../../../widgets/match/match_list_widgets.dart';

/// The gradient digital membership card shown at the top of the membership hub.
class DigitalMembershipCard extends StatelessWidget {
  const DigitalMembershipCard({
    super.key,
    required this.activeClub,
    required this.fanId,
    required this.membershipTier,
    required this.clubSplit,
  });

  final TeamModel? activeClub;
  final String? fanId;
  final String membershipTier;
  final int clubSplit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white70 : Colors.black54;
    final formattedFanId = fanId == null || fanId!.length < 6
        ? '— — —'
        : '${fanId!.substring(0, 3)} ${fanId!.substring(3)}';

    return FzCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [FzColors.primary, FzColors.secondary],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    membershipTier.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                if (activeClub != null)
                  TeamAvatar(
                    name: activeClub!.name,
                    logoUrl: activeClub!.logoUrl ?? activeClub!.crestUrl,
                    size: 42,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            activeClub != null
                ? Text(
                    activeClub!.name,
                    style: FzTypography.display(size: 28, color: Colors.white),
                  )
                : Text.rich(
                    TextSpan(
                      children: FzWordmark.spansForText(
                        'FANZONE Supporter',
                        style: FzTypography.display(
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 4),
            Text(
              activeClub == null
                  ? 'Join a club to activate your supporter registry card.'
                  : (activeClub!.leagueName ??
                        activeClub!.country ??
                        'Supporter registry'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CardStat(label: 'Fan ID', value: formattedFanId),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardStat(
                    label: 'Status',
                    value: activeClub == null ? 'PENDING' : 'ACTIVE',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardStat(label: 'FET Split', value: '$clubSplit%'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
