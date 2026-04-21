import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// Reusable status chip matching the source-of-truth `StatusChip.tsx`.
class FzStatusChip extends StatelessWidget {
  const FzStatusChip({
    super.key,
    required this.label,
    this.variant = StatusChipVariant.info,
  });

  final String label;
  final StatusChipVariant variant;

  // Convenience constructors
  factory FzStatusChip.success(String label) =>
      FzStatusChip(label: label, variant: StatusChipVariant.success);

  factory FzStatusChip.warning(String label) =>
      FzStatusChip(label: label, variant: StatusChipVariant.warning);

  factory FzStatusChip.danger(String label) =>
      FzStatusChip(label: label, variant: StatusChipVariant.danger);

  factory FzStatusChip.info(String label) =>
      FzStatusChip(label: label, variant: StatusChipVariant.info);

  @override
  Widget build(BuildContext context) {
    final palette = _resolve(variant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.color.withValues(alpha: 0.10),
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: palette.color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label.toUpperCase(),
        style: FzTypography.statusLabel(color: palette.color),
      ),
    );
  }

  static _ChipPalette _resolve(StatusChipVariant variant) {
    switch (variant) {
      case StatusChipVariant.success:
        return const _ChipPalette(FzColors.accent);
      case StatusChipVariant.warning:
        return const _ChipPalette(FzColors.warning);
      case StatusChipVariant.danger:
        return const _ChipPalette(FzColors.accent2);
      case StatusChipVariant.info:
        return const _ChipPalette(FzColors.darkText);
    }
  }
}

enum StatusChipVariant { success, warning, danger, info }

class _ChipPalette {
  const _ChipPalette(this.color);
  final Color color;
}
