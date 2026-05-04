import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';
import 'fz_card.dart';

/// Reusable eligibility notice for venue-linked FET settlement flows.
class FzEligibilityRuleCard extends StatelessWidget {
  const FzEligibilityRuleCard({
    super.key,
    this.title = 'Order unlocks rewards',
    this.description = '2h order needed',
  });

  static const defaultDescription =
      'Winning FET is paid only with a paid, non-cancelled order from the linked bar within 2 hours before the pool or game starts.';

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.compact,
      borderColor: FzColors.accent2.withValues(alpha: 0.35),
      color: FzColors.accent2.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(LucideIcons.receipt, color: FzColors.accent2, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FzTypography.textTheme(
                    Theme.of(context).brightness,
                  ).titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: FzTypography.textTheme(
                    Theme.of(context).brightness,
                  ).bodySmall?.copyWith(color: FzColors.darkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Info',
            onPressed: () => _showEligibilityInfo(context),
            icon: const Icon(
              LucideIcons.info,
              size: 18,
              color: FzColors.accent2,
            ),
          ),
        ],
      ),
    );
  }

  void _showEligibilityInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.receipt, color: FzColors.accent2),
                SizedBox(width: 10),
                Text(
                  'Reward Rule',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              defaultDescription,
              style: FzTypography.textTheme(
                Theme.of(context).brightness,
              ).bodyMedium?.copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
