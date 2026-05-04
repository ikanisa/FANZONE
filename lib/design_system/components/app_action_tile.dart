import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_icons.dart';
import 'app_svg_icon.dart';

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.color = AppColors.primary,
    this.trailing,
  });

  final AppIconName icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: AppRadii.buttonRadius,
              ),
              child: Center(child: AppSvgIcon(icon, color: color, size: 25)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metric(size: 24, color: color),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
