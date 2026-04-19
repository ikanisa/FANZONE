import 'package:flutter/material.dart';
import '../../theme/colors.dart';

/// Compact badge / chip for status indicators (LIVE, league labels, counts).
class FzBadge extends StatelessWidget {
  const FzBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.pulse = false,
    this.icon,
    this.fontSize = 10,
  });

  final String label;
  final Color? color;
  final Color? textColor;
  final bool pulse;
  final IconData? icon;
  final double fontSize;

  /// Live match badge.
  factory FzBadge.live() => const FzBadge(
    label: 'LIVE',
    color: FzColors.live,
    textColor: Colors.white,
    pulse: true,
    fontSize: 9,
  );

  /// Count badge (e.g. notification count).
  factory FzBadge.count(int count) => FzBadge(
    label: count.toString(),
    color: FzColors.accent,
    textColor: Colors.white,
    fontSize: 9,
  );

  @override
  Widget build(BuildContext context) {
    final bg = color ?? FzColors.darkSurface2;
    final fg = textColor ?? FzColors.darkText;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    return badge;
  }
}
