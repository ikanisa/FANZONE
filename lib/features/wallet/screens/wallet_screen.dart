import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../design_system/design_system.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_animated_counter.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/state_view.dart';
import '../../../services/wallet_service.dart';
import '../data/wallet_gateway.dart';
import '../widgets/wallet_screen_components.dart';
import '../../../widgets/common/fz_glass_loader.dart';

/// Rewards ledger screen — sports-gaming dark style.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletBalanceAsync = ref.watch(walletBalanceProvider);
    final transactionsAsync = ref.watch(transactionServiceProvider);
    final isVerified = ref.watch(isFullyAuthenticatedProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text(
            'REWARDS',
            style: FzTypography.sportsTitle(size: 36, color: FzColors.darkText),
          ),
          const SizedBox(height: 18),
          _WalletHero(
            balanceAsync: walletBalanceAsync,
            currency: currency,
            isVerified: isVerified,
          ),
          const SizedBox(height: 18),
          walletBalanceAsync.when(
            data: (balance) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Earned',
                        amount: balance.earnedFet,
                        positive: true,
                        icon: LucideIcons.arrowUpRight,
                        color: FzColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Reserved',
                        amount: balance.stakedFet,
                        positive: true,
                        showSign: false,
                        icon: LucideIcons.lock,
                        color: FzColors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Spent',
                        amount: balance.spentFet,
                        positive: false,
                        icon: LucideIcons.arrowDownLeft,
                        color: FzColors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Pending',
                        amount: balance.pendingFet,
                        positive: true,
                        showSign: false,
                        icon: LucideIcons.timer,
                        color: FzColors.gold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const _WalletStatsSkeleton(),
            error: (_, _) => _WalletStatsUnavailable(
              onRetry: () {
                ref.invalidate(walletBalanceProvider);
                ref.invalidate(transactionServiceProvider);
              },
            ),
          ),
          const SizedBox(height: 28),
          const AppSectionHeader(title: 'History'),
          const SizedBox(height: 10),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const _HistoryEmptyState();
              }
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < transactions.length;
                      index++
                    ) ...[
                      if (index > 0) const Divider(height: 0.5, indent: 52),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: InkWell(
                          borderRadius: AppRadii.cardRadius,
                          onTap: () => context.push(
                            '/wallet/transaction/${transactions[index].id}',
                          ),
                          child: WalletTransactionRow(
                            transaction: transactions[index],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: FzGlassLoader(message: 'Syncing...'),
            ),
            error: (_, _) => StateView.error(
              title: 'Load failed',
              onRetry: () => ref.invalidate(transactionServiceProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({
    required this.balanceAsync,
    required this.currency,
    required this.isVerified,
  });

  final AsyncValue<WalletBalance> balanceAsync;
  final String currency;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.wallet,
        borderRadius: FzRadii.heroRadius,
        boxShadow: [
          BoxShadow(
            color: FzColors.orange.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -36,
            child: Icon(
              LucideIcons.wallet,
              size: 180,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Column(
            children: [
              Text(
                'FET REWARDS',
                style: FzTypography.chipLabel(size: 12, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              balanceAsync.when(
                data: (balance) => Column(
                  children: [
                    FzAnimatedCounter(
                      key: const ValueKey('wallet-total-balance-value'),
                      value: balance.availableFet.toDouble(),
                      style: FzTypography.heroFet(
                        size: 48,
                        color: Colors.white,
                      ),
                      formatter: (v) => formatFETCompact(v.round()),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatFET(balance.availableFet, currency),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                loading: () => Text(
                  '...',
                  style: FzTypography.heroFet(size: 48, color: Colors.white70),
                ),
                error: (_, _) => Text(
                  '—',
                  style: FzTypography.heroFet(size: 48, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 18),
              _RewardsLedgerNotice(isVerified: isVerified),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardsLedgerNotice extends StatelessWidget {
  const _RewardsLedgerNotice({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldCheck, size: 18, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isVerified
                  ? 'FET is a closed-loop rewards ledger for venue rewards, games, and coupons.'
                  : 'Verify to keep your rewards ledger and order history protected.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStatsSkeleton extends StatelessWidget {
  const _WalletStatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatCardPlaceholder()),
        SizedBox(width: 10),
        Expanded(child: _StatCardPlaceholder()),
      ],
    );
  }
}

class _WalletStatsUnavailable extends StatelessWidget {
  const _WalletStatsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(child: _StatUnavailableCard(label: 'Earned')),
            SizedBox(width: 10),
            Expanded(child: _StatUnavailableCard(label: 'Spent')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              LucideIcons.alertTriangle,
              size: 14,
              color: FzColors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unavailable.',
                style: AppTypography.secondary.copyWith(
                  color: FzColors.darkMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: FzColors.cyan,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCardPlaceholder extends StatelessWidget {
  const _StatCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const FzCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            height: 10,
            child: ColoredBox(color: FzColors.darkSurface3),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: 96,
            height: 14,
            child: ColoredBox(color: FzColors.darkSurface3),
          ),
        ],
      ),
    );
  }
}

class _StatUnavailableCard extends StatelessWidget {
  const _StatUnavailableCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.status(color: FzColors.darkMuted)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '—',
            style: AppTypography.label.copyWith(color: FzColors.orange),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const FzEmptyState(
      title: 'No history',
      description: 'Start earning.',
      icon: Icon(LucideIcons.receipt, size: 24),
    );
  }
}
