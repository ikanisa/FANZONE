import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// Admin metric card matching the reference `AdminMetricCard.tsx`.
///
/// Displays a label, large numeric value, and optional trend indicator.
/// Used in admin dashboards and analytics screens.
class FzAdminMetricCard extends StatelessWidget {
  const FzAdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendUp,
  });

  final String label;
  final String value;
  final String? trend;
  final bool? trendUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FzColors.darkSurface3,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: FzTypography.metaLabel(size: 10),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: FzTypography.score(size: 28),
          ),
          if (trend != null) ...[
            const SizedBox(height: 6),
            Text(
              trend!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: trendUp == true
                    ? FzColors.primary
                    : FzColors.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
