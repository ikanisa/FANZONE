import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../typography/app_typography.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            label,
            style: AppTypography.secondary.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
