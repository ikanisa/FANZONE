import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// Unified empty-state surface aligned with the reference FANZONE component.
class FzEmptyState extends StatelessWidget {
  const FzEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(32),
    this.maxWidth = 360,
  });

  final String title;
  final String description;
  final Widget? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final surface3 = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: CustomPaint(
          painter: _DashedRoundedRectPainter(
            color: border,
            radius: FzRadii.card,
          ),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: surface2,
              borderRadius: FzRadii.cardRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: surface3,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: IconTheme.merge(
                    data: IconThemeData(color: muted, size: 24),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: muted),
                      child:
                          icon ??
                          const Text('📦', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: FzTypography.display(
                    size: 24,
                    color: text,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: muted, height: 1.45),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: surface3,
                      foregroundColor: text,
                      side: BorderSide(color: border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final currentDash = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, currentDash.toDouble()),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dash != oldDelegate.dash ||
        gap != oldDelegate.gap;
  }
}
