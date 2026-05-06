import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';

/// Full-width cyan pill CTA button.
///
/// Height: 64–72px. Cyan background, dark text.
/// Max 3 words on label. Used for Join, Create, Order, Pay, etc.
class AppPrimaryCta extends StatelessWidget {
  const AppPrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = FzSpacing.ctaHeight,
    this.color = FzColors.accent,
    this.textColor = FzColors.onAction,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color color;
  final Color textColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.35);
    final effectiveTextColor = enabled
        ? textColor
        : textColor.withValues(alpha: 0.7);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: effectiveColor,
        borderRadius: FzRadii.fullRadius,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: FzRadii.fullRadius,
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: effectiveTextColor),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: effectiveTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
