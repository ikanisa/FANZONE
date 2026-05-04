import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_icons.dart';
import 'app_svg_icon.dart';

class AppQuickAction extends StatelessWidget {
  const AppQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final AppIconName icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: AppRadii.buttonRadius,
              ),
              child: Center(child: AppSvgIcon(icon, color: color, size: 24)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
