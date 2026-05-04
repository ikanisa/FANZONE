import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import '../../design_system/components/app_button.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/typography/app_typography.dart';

/// Unified view for empty, error, and loading states.
///
/// Every async surface in the app should use this to avoid blank screens.
class StateView extends StatelessWidget {
  const StateView._({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;
  final String? actionLabel;

  /// Empty state — no data to show.
  factory StateView.empty({
    String title = 'Nothing yet',
    String subtitle = 'Check later.',
    IconData icon = LucideIcons.inbox,
    VoidCallback? action,
    String? actionLabel,
  }) => StateView._(
    icon: icon,
    title: title,
    subtitle: subtitle,
    action: action,
    actionLabel: actionLabel,
  );

  /// Error state — something went wrong.
  factory StateView.error({
    String title = 'Error',
    String subtitle = 'Try again.',
    VoidCallback? onRetry,
  }) => StateView._(
    icon: LucideIcons.alertTriangle,
    title: title,
    subtitle: subtitle,
    action: onRetry,
    actionLabel: 'Retry',
  );

  /// Offline state — no network.
  factory StateView.offline({VoidCallback? onRetry}) => StateView._(
    icon: LucideIcons.wifiOff,
    title: 'Offline',
    subtitle: 'Reconnect.',
    action: onRetry,
    actionLabel: 'Retry',
  );

  /// Auto-detect: returns [offline] for network errors, [error] otherwise.
  factory StateView.fromError(Object error, {VoidCallback? onRetry}) {
    if (error is SocketException || error is TimeoutException) {
      return StateView.offline(onRetry: onRetry);
    }
    return StateView.error(onRetry: onRetry);
  }

  @override
  Widget build(BuildContext context) {
    final isErrorState =
        icon == LucideIcons.alertTriangle || icon == LucideIcons.wifiOff;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - 64).clamp(0.0, double.infinity)
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceRaised,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 24, color: AppColors.muted),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      title,
                      style: AppTypography.h3(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle,
                      style: AppTypography.secondary.copyWith(
                        color: AppColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (action != null) ...[
                      const SizedBox(height: AppSpacing.xxxl),
                      AppButton(
                        label: actionLabel ?? 'Retry',
                        onPressed: action,
                        variant: isErrorState
                            ? AppButtonVariant.primary
                            : AppButtonVariant.secondary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
