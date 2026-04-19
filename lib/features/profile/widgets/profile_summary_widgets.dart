import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/notification_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProfileStatCard(
            label: 'Streak',
            value: '${stats.predictionStreak}',
            accent: FzColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ProfileStatCard(
            label: 'Predictions',
            value: '${stats.totalPredictions}',
            accent: FzColors.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ProfileStatCard(
            label: 'Pools Won',
            value: '${stats.totalPoolsWon}',
            accent: FzColors.success,
          ),
        ),
      ],
    );
  }
}

class ProfileWalletCard extends ConsumerWidget {
  const ProfileWalletCard({
    super.key,
    required this.balanceAsync,
    required this.muted,
    this.onTap,
  });

  final AsyncValue<int> balanceAsync;
  final Color muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.amber.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FzColors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.wallet,
              color: FzColors.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FET Balance',
                  style: TextStyle(
                    fontSize: 11,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                balanceAsync.when(
                  data: (balance) {
                    final currency =
                        ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
                    return Text(
                      formatFET(balance, currency),
                      style: FzTypography.scoreLarge(color: FzColors.amber),
                    );
                  },
                  loading: () => Text(
                    '...',
                    style: FzTypography.scoreLarge(color: FzColors.amber),
                  ),
                  error: (_, _) => Text(
                    '—',
                    style: FzTypography.scoreLarge(color: FzColors.amber),
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: muted),
        ],
      ),
    );
  }
}

class ProfileStatCard extends StatelessWidget {
  const ProfileStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      borderColor: accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: FzTypography.scoreLarge(color: accent)),
        ],
      ),
    );
  }
}
