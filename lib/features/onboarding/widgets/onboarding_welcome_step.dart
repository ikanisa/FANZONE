import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/typography.dart';
import '../../../widgets/common/fz_wordmark.dart';
import 'onboarding_step_chrome.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onNext,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            FzWordmark(style: FzTypography.display(size: 64, letterSpacing: 0)),
            const SizedBox(height: 44),
            OnboardingFeatureRow(
              icon: LucideIcons.store,
              title: 'Find the right bar',
              description: 'See venues, match nights, and service context.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const SizedBox(height: 22),
            OnboardingFeatureRow(
              icon: LucideIcons.trophy,
              title: 'Choose your teams',
              description: 'Add one local club and your top European sides.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const SizedBox(height: 22),
            OnboardingFeatureRow(
              icon: LucideIcons.zap,
              title: 'Play on match day',
              description: 'Join venue games and collect closed-loop FET.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const Spacer(),
            OnboardingPrimaryButton(
              key: const ValueKey('onboarding_get_started'),
              label: 'GET STARTED',
              onTap: onNext,
              showChevron: true,
            ),
          ],
        ),
      ),
    );
  }
}
