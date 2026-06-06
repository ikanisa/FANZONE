import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/platform_feature_access.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

/// Production-safe fallback for routes backed by disabled or unfinished features.
class FeatureUnavailableScreen extends ConsumerWidget {
  const FeatureUnavailableScreen({
    super.key,
    required this.featureName,
    this.message,
  });

  final String featureName;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkBg : FzColors.lightBg;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final access = ref.watch(platformFeatureAccessProvider);
    final displayName = _displayFeatureName(access, featureName);

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
                    '$displayName unavailable',
                    style: FzTypography.display(
                      size: 24,
                      color: text,
                      letterSpacing: 0,
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
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/home');
                            }
                          },
                          icon: const Icon(LucideIcons.chevronLeft, size: 16),
                          label: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/home'),
                          icon: const Icon(LucideIcons.home, size: 16),
                          label: const Text('Home'),
                        ),
                      ),
                    ],
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

String _displayFeatureName(PlatformFeatureAccess access, String featureName) {
  final label = access.labelFor(featureName).trim();
  if (label.isNotEmpty && label != featureName) return label;

  final words = featureName
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .toList(growable: false);
  if (words.isEmpty) return 'Feature';
  return words.join(' ');
}
