import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../design_system/design_system.dart';
import '../../../models/auth_and_user/wallet.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';

class WalletSummaryCard extends ConsumerWidget {
  const WalletSummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.positive,
    required this.icon,
    required this.color,
    this.showSign = true,
  });

  final String label;
  final int amount;
  final bool positive;
  final IconData icon;
  final Color color;
  final bool showSign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.status(
                    color: AppColors.muted.withValues(alpha: 0.86),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${showSign ? (positive ? '+' : '-') : ''}${NumberFormat.compact().format(amount).toLowerCase()}',
                  style: AppTypography.metric(size: 18, color: color),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
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
        transaction.type == 'order_earn' ||
        transaction.type == 'welcome_credit' ||
        transaction.type == 'pool_win' ||
        transaction.type == 'pool_refund' ||
        transaction.type == 'creator_reward' ||
        transaction.type == 'transfer_received' ||
        transaction.type == 'bonus' ||
        transaction.type == 'pending';
    final color = isEarn ? FzColors.success : FzColors.danger;
    final icon = _iconForType(transaction.type);
    final prefix = isEarn ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: AppTypography.label.copyWith(fontSize: 15),
                ),
                Text(
                  transaction.dateStr,
                  style: AppTypography.secondary.copyWith(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${formatFETCompact(transaction.amount)}',
            style: AppTypography.metric(size: 16, color: color),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'earn':
      case 'order_earn':
        return LucideIcons.target;
      case 'welcome_credit':
        return LucideIcons.gift;
      case 'pool_win':
      case 'creator_reward':
        return LucideIcons.trophy;
      case 'pool_refund':
        return LucideIcons.rotateCcw;
      case 'spend':
      case 'order_spend':
        return LucideIcons.swords;
      case 'pool_stake':
        return LucideIcons.lock;
      case 'pending':
        return LucideIcons.timer;
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
