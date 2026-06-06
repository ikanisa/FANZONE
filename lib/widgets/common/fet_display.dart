import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency_utils.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Reusable FET amount display for closed-loop reward points.
///
/// Renders: "FET 1,000" or "+ FET 500"
///
/// Usage:
/// ```dart
/// FETDisplay(amount: 500)
/// FETDisplay(amount: 300, showSign: true, positive: false)
/// ```
class FETDisplay extends ConsumerWidget {
  const FETDisplay({
    super.key,
    required this.amount,
    this.style,
    this.showSign = false,
    this.positive = true,
    this.fetStyle,
    this.localStyle,
  });

  /// The FET amount to display.
  final int amount;

  /// Optional override for the entire text style.
  final TextStyle? style;

  /// Whether to show +/- prefix.
  final bool showSign;

  /// If [showSign] is true, whether the sign is + or -.
  final bool positive;

  /// Optional style for just the FET portion.
  final TextStyle? fetStyle;

  /// Optional style for just the local currency portion.
  final TextStyle? localStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = showSign
        ? '${positive ? '+' : '-'} ${formatFETCompact(amount)}'
        : formatFETCompact(amount);

    return Text(text, style: style ?? fetStyle);
  }
}

/// Inline FET text span for use in RichText / TextSpan trees.
class FETDisplaySpan extends ConsumerWidget {
  const FETDisplaySpan({
    super.key,
    required this.amount,
    this.fetColor,
    this.localColor,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.showSign = false,
    this.positive = true,
  });

  final int amount;
  final Color? fetColor;
  final Color? localColor;
  final double fontSize;
  final FontWeight fontWeight;
  final bool showSign;
  final bool positive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fetStr = formatFETCompact(amount);
    final sign = showSign ? (positive ? '+ ' : '- ') : '';

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$sign$fetStr ',
            style: FzTypography.score(
              size: fontSize,
              weight: fontWeight,
              color:
                  fetColor ?? (isDark ? FzColors.darkText : FzColors.lightText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Balance pill for profile screen.
///
/// Renders: "FET 15,000" in a styled pill container.
class FETBalancePill extends ConsumerWidget {
  const FETBalancePill({super.key, required this.balance, this.onTap});

  final int balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FzColors.primary.withValues(alpha: 0.15),
              FzColors.secondary.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FzColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          formatFETCompact(balance),
          style: FzTypography.score(
            size: 14,
            weight: FontWeight.w700,
            color: FzColors.primary,
          ),
        ),
      ),
    );
  }
}
