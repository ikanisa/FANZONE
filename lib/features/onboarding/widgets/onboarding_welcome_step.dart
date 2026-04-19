import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
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
            Text(
              'FANZONE',
              style: FzTypography.display(
                size: 64,
                color: textColor,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'PREDICT. EARN. REPEAT.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FzColors.accent,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 40),
            OnboardingFeatureRow(
              icon: LucideIcons.zap,
              title: 'Live Predictions',
              description: 'Predict match outcomes in real-time.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            OnboardingFeatureRow(
              icon: LucideIcons.trophy,
              title: 'Earn FET Tokens',
              description: 'Get rewarded for your football knowledge.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            OnboardingFeatureRow(
              icon: LucideIcons.shieldCheck,
              title: '100% Free to Play',
              description: 'No stakes, no risk. Just pure fandom.',
              textColor: textColor,
              muted: muted,
              isDark: isDark,
            ),
            const Spacer(),
            OnboardingPrimaryButton(label: 'GET STARTED', onTap: onNext),
          ],
        ),
      ),
    );
  }
}
