import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

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
    final bg = isDark ? FzColors.darkBg : FzColors.lightBg;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FzCard(
              color: surface,
              borderRadius: FzRadii.card,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: FzColors.accent.withValues(alpha: 0.12),
                      borderRadius: FzRadii.fullRadius,
                      border: Border.all(
                        color: FzColors.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      'UNAVAILABLE',
                      style: FzTypography.metaLabel(color: FzColors.accent),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: FzColors.darkSurface3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: FzColors.darkBorder),
                    ),
                    child: const Icon(
                      LucideIcons.lock,
                      color: FzColors.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$featureName IS NOT LIVE',
                    style: FzTypography.display(
                      size: 24,
                      color: text,
                      letterSpacing: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message ??
                        'This route is not part of the active FANZONE build for this release.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: muted,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
