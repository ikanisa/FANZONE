import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';

/// Reusable card container matching FANZONE design system.
class FzCard extends StatelessWidget {
  const FzCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius = FzRadii.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final radius = BorderRadius.circular(borderRadius);
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;
    final materialContent = Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              splashColor: FzColors.primary.withValues(alpha: 0.08),
              highlightColor: FzColors.primary.withValues(alpha: 0.04),
              borderRadius: radius,
              child: content,
            ),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? (isDark ? FzColors.darkSurface : FzColors.lightSurface),
        borderRadius: radius,
        border: Border.all(
          color:
              borderColor ??
              (isDark ? FzColors.darkBorder : FzColors.lightBorder),
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: materialContent,
    );
  }
}
