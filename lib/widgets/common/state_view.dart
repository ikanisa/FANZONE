import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

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
    String title = 'Nothing here yet',
    String subtitle = 'Check back later.',
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
    String title = 'Something went wrong',
    String subtitle = 'Please try again.',
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
    title: 'You\'re offline',
    subtitle: 'Connect to the internet and try again.',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final surface3 = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final isErrorState =
        icon == LucideIcons.alertTriangle || icon == LucideIcons.wifiOff;
    final actionColor = isErrorState ? FzColors.accent2 : text;
    final actionBackground = isErrorState
        ? FzColors.accent2.withValues(alpha: 0.10)
        : surface3;
    final actionBorder = isErrorState
        ? FzColors.accent2.withValues(alpha: 0.20)
        : border;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - 64).clamp(0.0, double.infinity)
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: FzRadii.cardRadius,
                  border: Border.all(color: border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: surface3,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 24, color: muted),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: FzTypography.display(
                        size: 24,
                        color: text,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: muted, height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 32),
                      InkWell(
                        onTap: action,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: actionBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: actionBorder),
                          ),
                          child: Text(
                            actionLabel ?? 'Try again',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: actionColor,
                            ),
                          ),
                        ),
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
