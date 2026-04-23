import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:fanzone/theme/colors.dart';
import 'package:fanzone/widgets/common/fz_animated_entry.dart';
import 'package:fanzone/widgets/common/fz_badge.dart';
import 'package:fanzone/widgets/common/fz_card.dart';
import 'package:fanzone/widgets/common/team_crest.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('design system gallery matches dark golden', (tester) async {
    await pumpAppScreen(
      tester,
      const _DesignSystemGallery(),
      surfaceSize: const Size(900, 720),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('design-system-gallery')),
      matchesGoldenFile('goldens/design_system_components.dark.png'),
    );
  });
}

class _DesignSystemGallery extends StatelessWidget {
  const _DesignSystemGallery();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      body: Center(
        child: Container(
          key: const ValueKey('design-system-gallery'),
          width: 840,
          padding: const EdgeInsets.all(32),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FANZONE Design System',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FzBadge.live(),
                  FzBadge.count(7),
                  const FzBadge(
                    label: 'FEATURED',
                    color: FzColors.coral,
                    textColor: Colors.white,
                    icon: LucideIcons.flame,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const TeamCrest(label: 'Test Club A', size: 56),
                  const SizedBox(width: 16),
                  const TeamCrest(
                    label: 'Test Club B',
                    fallbackEmoji: '⚽',
                    size: 56,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FzCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Primary Card',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Surface, border, typography, and badge behavior should stay aligned with the reference UI.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FzAnimatedEntry(
                child: FzCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: FzColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reduced-motion users should see the final state without delayed fades or slides.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
