import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// Status chip with colored dot indicator — per reference.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.color = FzColors.cyan,
    this.showDot = true,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool showDot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label.toUpperCase(),
            style: FzTypography.chipLabel(size: 12, color: color),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: FzRadii.fullRadius,
      child: content,
    );
  }
}
