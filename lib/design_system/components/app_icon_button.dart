import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import 'app_icons.dart';
import 'app_svg_icon.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = AppColors.primary,
    this.backgroundColor,
  });

  final AppIconName icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadii.buttonRadius,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: (backgroundColor ?? color.withValues(alpha: 0.12)),
            borderRadius: AppRadii.buttonRadius,
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          alignment: Alignment.center,
          child: AppSvgIcon(icon, size: 21, color: color),
        ),
      ),
    );
  }
}
