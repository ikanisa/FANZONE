import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/runtime/app_runtime_state.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/typography/app_typography.dart';

class FzOfflineBanner extends StatelessWidget {
  const FzOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appRuntime.isOffline,
      builder: (context, isOffline, child) {
        if (!isOffline) return const SizedBox.shrink();

        return Material(
          color: AppColors.warning,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.wifiOff,
                    size: 16,
                    color: AppColors.background,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Offline mode - viewing cached data',
                      style: AppTypography.label.copyWith(
                        fontSize: 13,
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
