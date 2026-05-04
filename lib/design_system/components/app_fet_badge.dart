import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// FET badge — orange accent, large number display.
class AppFetBadge extends StatelessWidget {
  const AppFetBadge({
    super.key,
    required this.amount,
    this.size = 24,
    this.showIcon = true,
    this.color = FzColors.orange,
  });

  final int amount;
  final double size;
  final bool showIcon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(LucideIcons.zap, size: size * 0.65, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            '$amount',
            style: FzTypography.chipLabel(size: size * 0.58, color: color),
          ),
          const SizedBox(width: 3),
          Text(
            'FET',
            style: FzTypography.chipLabel(size: size * 0.45, color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
