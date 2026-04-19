import 'package:flutter/material.dart';
import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import '../../theme/colors.dart';

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
    IconData icon = Icons.inbox_outlined,
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
    icon: Icons.warning_amber_rounded,
    title: title,
    subtitle: subtitle,
    action: onRetry,
    actionLabel: 'Retry',
  );

  /// Offline state — no network.
  factory StateView.offline({VoidCallback? onRetry}) => StateView._(
    icon: Icons.wifi_off_rounded,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark
                          ? FzColors.darkSurface2
                          : FzColors.lightSurface2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: muted),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: action,
                      child: Text(actionLabel ?? 'Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
