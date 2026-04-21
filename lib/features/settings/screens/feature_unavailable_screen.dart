import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

/// Production-safe fallback for routes backed by disabled or unfinished features.
class FeatureUnavailableScreen extends StatelessWidget {
  const FeatureUnavailableScreen({
    super.key,
    required this.featureName,
    this.message,
  });

  final String featureName;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: FzColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.lock,
                    color: FzColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$featureName is unavailable in this build',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message ??
                      'This route is disabled until the production backend and release configuration are ready.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
