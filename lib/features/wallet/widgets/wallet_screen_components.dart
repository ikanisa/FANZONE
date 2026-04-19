import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatFETSigned(amount, currency, positive: positive),
            style: FzTypography.scoreCompact(color: color),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isActive)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: FzColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        Flexible(
          child: Text(
            tier,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? FzColors.accent : muted,
            ),
          ),
        ),
      ],
    );
    final splitBar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            Expanded(
              flex: walletPct,
              child: Container(color: FzColors.accent),
            ),
            if (clubPct > 0)
              Expanded(
                flex: clubPct,
                child: Container(color: FzColors.amber),
              ),
          ],
        ),
      ),
    );
    final ratio = Text(
      '$walletPct / $clubPct',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      textAlign: TextAlign.right,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  ratio,
                ],
              ),
              const SizedBox(height: 8),
              splitBar,
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 88, child: label),
            const SizedBox(width: 8),
            Expanded(child: splitBar),
            const SizedBox(width: 8),
            SizedBox(width: 48, child: ratio),
          ],
        );
      },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLUB EARNINGS SPLIT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Club earnings split stays visible here so wallet growth and club support never feel disconnected.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        '80% YOU',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: FzColors.teal,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        '20% CLUB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: FzColors.accent,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 80,
                            child: Container(color: FzColors.teal),
                          ),
                          Expanded(
                            flex: 20,
                            child: Container(color: FzColors.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ultra is the active launch tier reference.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              WalletFetSplitRow(
                tier: 'Supporter',
                walletPct: 100,
                clubPct: 0,
                isActive: false,
                muted: muted,
              ),
              const SizedBox(height: 8),
              WalletFetSplitRow(
                tier: 'Member',
                walletPct: 90,
                clubPct: 10,
                isActive: false,
                muted: muted,
              ),
              const SizedBox(height: 8),
              WalletFetSplitRow(
                tier: 'Ultra',
                walletPct: 80,
                clubPct: 20,
                isActive: true,
                muted: muted,
              ),
              const SizedBox(height: 8),
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
