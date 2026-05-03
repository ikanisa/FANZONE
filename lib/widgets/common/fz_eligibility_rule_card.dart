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
    this.title = 'FET settlement eligibility',
    this.description = defaultDescription,
  });

  static const defaultDescription =
      'Winning FET is paid only with a paid, non-cancelled order from the linked bar within 2 hours before the pool or game starts.';

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      borderColor: FzColors.accent2.withValues(alpha: 0.35),
      color: FzColors.accent2.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 6),
                Text(
                  description,
                  style: FzTypography.textTheme(
                    Theme.of(context).brightness,
                  ).bodySmall?.copyWith(color: FzColors.darkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
