import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
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
            FzWordmark(style: FzTypography.display(size: 64, letterSpacing: 4)),
            const SizedBox(height: 4),
            const Text(
              'ORDER. POOL. EARN.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FzColors.primary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 44),
            OnboardingFeatureRow(
              icon: LucideIcons.zap,
              title: 'Match Pools',
              description: 'Join venue-linked FET pools.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const SizedBox(height: 22),
            OnboardingFeatureRow(
              icon: LucideIcons.trophy,
              title: 'Earn FET',
              description: 'Earn from venue orders and settled pools.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const SizedBox(height: 22),
            OnboardingFeatureRow(
              icon: LucideIcons.shieldCheck,
              title: 'Anonymous Profile',
              description: 'Play securely without identity exposure.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const Spacer(),
            OnboardingPrimaryButton(
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
