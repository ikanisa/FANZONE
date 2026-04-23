import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/wallet.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

class WalletSummaryCard extends ConsumerWidget {
  const WalletSummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.positive,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final bool positive;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface;
    return FzCard(
      color: surface,
      borderRadius: 20,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: muted.withValues(alpha: 0.8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${positive ? '+' : '-'}${NumberFormat.compact().format(amount).toLowerCase()}',
                  style: FzTypography.score(
                    size: 16,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ],
      ),
    );
  }
}

class WalletTransactionRow extends ConsumerWidget {
  const WalletTransactionRow({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userCurrencyProvider);
    final isEarn =
        transaction.type == 'earn' ||
        transaction.type == 'transfer_received' ||
        transaction.type == 'bonus';
    final color = isEarn ? FzColors.success : FzColors.danger;
    final icon = _iconForType(transaction.type);
    final prefix = isEarn ? '+' : '-';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 11, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                Text(
                  transaction.dateStr,
                  style: TextStyle(
                    fontSize: 8,
                    color: muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${formatFETCompact(transaction.amount)}',
            style: FzTypography.score(
              size: 10,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'earn':
        return LucideIcons.target;
      case 'spend':
        return LucideIcons.swords;
      case 'transfer_sent':
        return LucideIcons.arrowUpRight;
      case 'transfer_received':
        return LucideIcons.arrowDownLeft;
      case 'bonus':
        return LucideIcons.gift;
      default:
        return LucideIcons.receipt;
    }
  }
}
