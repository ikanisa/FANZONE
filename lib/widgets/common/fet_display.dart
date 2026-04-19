import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency_utils.dart';
import '../../providers/currency_provider.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Reusable FET amount display with local currency equivalent.
///
/// Renders: "FET 1,000 (€10)" or "+ FET 500 (FRW 7,000)"
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
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    final text = showSign
        ? formatFETSigned(amount, currency, positive: positive)
        : formatFET(amount, currency);

    return Text(
      text,
      style: style ?? fetStyle,
    );
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
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    final fetStr = formatFETCompact(amount);
    final localAmount = fetToLocal(amount, currency);
    final info = currencies[currency] ?? currencies['EUR']!;

    String localStr;
    if (info.decimals == 0) {
      localStr = '${info.symbol} ${_formatNumber(localAmount.round())}';
    } else {
      localStr =
          '${info.symbol}${localAmount.toStringAsFixed(info.decimals)}';
    }

    final sign = showSign ? (positive ? '+ ' : '- ') : '';

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$sign$fetStr ',
            style: FzTypography.score(
              size: fontSize,
              weight: fontWeight,
              color: fetColor ??
                  (isDark ? FzColors.darkText : FzColors.lightText),
            ),
          ),
          TextSpan(
            text: '($localStr)',
            style: TextStyle(
              fontSize: fontSize * 0.85,
              fontWeight: FontWeight.w500,
              color: localColor ?? muted,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000) {
      return value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return value.toString();
  }
}

/// Balance pill for profile screen.
///
/// Renders: "FET 15,000 (€150)" in a styled pill container.
class FETBalancePill extends ConsumerWidget {
  const FETBalancePill({
    super.key,
    required this.balance,
    this.onTap,
  });

  final int balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FzColors.accent.withValues(alpha: 0.15),
              FzColors.blue.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: FzColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          formatFET(balance, currency),
          style: FzTypography.score(
            size: 14,
            weight: FontWeight.w700,
            color: FzColors.accent,
          ),
        ),
      ),
    );
  }
}
