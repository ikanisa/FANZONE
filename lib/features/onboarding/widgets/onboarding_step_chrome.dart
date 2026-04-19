import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

class OnboardingBackButtonRow extends StatelessWidget {
  const OnboardingBackButtonRow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onBack,
        icon: const Icon(LucideIcons.chevronLeft),
      ),
    );
  }
}

class OnboardingFeatureRow extends StatelessWidget {
  const OnboardingFeatureRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.textColor,
    required this.muted,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color textColor;
  final Color muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
            border: Border.all(
              color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            ),
          ),
          child: Icon(icon, size: 20, color: FzColors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: FzColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: FzColors.accent.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}

class OnboardingSectionTitle extends StatelessWidget {
  const OnboardingSectionTitle({
    super.key,
    required this.title,
    required this.textColor,
    this.size = 40,
  });

  final String title;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: FzTypography.display(size: size, color: textColor),
    );
  }
}
