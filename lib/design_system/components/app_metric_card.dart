import 'package:flutter/material.dart';

import 'app_card.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../typography/app_typography.dart';

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.icon,
  });

  final String label;
  final String value;
  final String? detail;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTypography.status(color: AppColors.muted),
                ),
              ),
              ?icon,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTypography.metric(size: 34)),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              detail!,
              style: AppTypography.secondary.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
