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

class WalletActionButton extends StatelessWidget {
  const WalletActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

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

class WalletMetaChip extends StatelessWidget {
  const WalletMetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class WalletTransactionRow extends ConsumerWidget {
  const WalletTransactionRow({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEarn =
        transaction.type == 'earn' ||
        transaction.type == 'transfer_received' ||
        transaction.type == 'bonus';
    final color = isEarn ? FzColors.success : FzColors.danger;
    final icon = _iconForType(transaction.type);
    final prefix = isEarn ? '+' : '-';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  transaction.dateStr,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          Text(
            '$prefix ${formatFET(transaction.amount, currency)}',
            style: FzTypography.scoreCompact(color: color),
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

class WalletFetSplitRow extends StatelessWidget {
  const WalletFetSplitRow({
    super.key,
    required this.tier,
    required this.walletPct,
    required this.clubPct,
    required this.isActive,
    required this.muted,
  });

  final String tier;
  final int walletPct;
  final int clubPct;
  final bool isActive;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? FzColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? FzColors.primary.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tier,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? FzColors.primary : textColor,
              letterSpacing: 0.8,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$walletPct%',
                style: FzTypography.score(
                  size: 10,
                  weight: FontWeight.w700,
                  color: FzColors.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('|', style: TextStyle(fontSize: 10, color: muted)),
              ),
              Text(
                '$clubPct%',
                style: FzTypography.score(
                  size: 10,
                  weight: FontWeight.w700,
                  color: FzColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WalletFetSplitModelCard extends StatelessWidget {
  const WalletFetSplitModelCard({
    super.key,
    required this.isDark,
    required this.muted,
  });

  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface;
    final titleColor = isDark ? FzColors.darkText : FzColors.lightText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.pieChart, size: 14, color: FzColors.primary),
            const SizedBox(width: 8),
            Text(
              'Club Earnings Split',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FzCard(
          color: surface,
          borderRadius: 20,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '80% YOU',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: FzColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '20% CLUB',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: FzColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 80,
                        child: ColoredBox(color: FzColors.primary),
                      ),
                      Expanded(
                        flex: 20,
                        child: ColoredBox(color: FzColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              WalletFetSplitRow(
                tier: 'Supporter',
                walletPct: 100,
                clubPct: 0,
                isActive: false,
                muted: muted,
              ),
              const SizedBox(height: 4),
              WalletFetSplitRow(
                tier: 'Member',
                walletPct: 90,
                clubPct: 10,
                isActive: false,
                muted: muted,
              ),
              const SizedBox(height: 4),
              WalletFetSplitRow(
                tier: 'Ultra',
                walletPct: 80,
                clubPct: 20,
                isActive: true,
                muted: muted,
              ),
              const SizedBox(height: 4),
              WalletFetSplitRow(
                tier: 'Legend',
                walletPct: 65,
                clubPct: 35,
                isActive: false,
                muted: muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
