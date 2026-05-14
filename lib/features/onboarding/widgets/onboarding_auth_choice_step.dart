import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_wordmark.dart';

class OnboardingAuthChoiceStep extends StatelessWidget {
  const OnboardingAuthChoiceStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.onWhatsApp,
  });

  final Color textColor;
  final Color muted;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),

            // Title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JOIN',
                  style: FzTypography.display(
                    size: 48,
                    color: textColor,
                    letterSpacing: 2,
                  ),
                ),
                FzWordmark(
                  style: FzTypography.display(size: 48, letterSpacing: 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Verify with WhatsApp to continue',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 40),

            // WhatsApp CTA
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onWhatsApp,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: FzColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.messageCircle, size: 20),
                    SizedBox(width: 10),
                    Text('CONTINUE WITH WHATSAPP'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            const Spacer(),

            // Privacy notice
            Center(
              child: Text(
                'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: muted.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
