import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_animated_counter.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../../services/wallet_service.dart';
import '../widgets/wallet_screen_components.dart';
import '../widgets/wallet_transfer_sheets.dart';

/// Wallet screen aligned to the primary reference wallet hub.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletServiceProvider);
    final transactionsAsync = ref.watch(transactionServiceProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(LucideIcons.wallet, size: 22, color: FzColors.accent),
            const SizedBox(width: 10),
            Text(
              'Wallet',
              style: FzTypography.display(
                size: 34,
                color: FzColors.darkText,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          _WalletHero(
            balanceAsync: balanceAsync,
            currency: currency,
            onRedeem: ref.watch(featureFlagsProvider).rewards || ref.watch(featureFlagsProvider).marketplace
                ? () => context.push('/rewards')
                : null,
            onSend: () {
              if (!isAuthenticated) {
                showSignInRequiredSheet(
                  context,
                  title: 'Sign in to transfer FET',
                  message:
                      'Phone verification is only required when you want to send FET to another fan.',
                  from: '/wallet',
                );
                return;
              }

              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const TransferFetSheet(),
              );
            },
          ),
          const SizedBox(height: 18),
          balanceAsync.when(
            data: (_) => transactionsAsync.when(
              data: (transactions) {
                final earned = transactions
                    .where(
                      (tx) =>
                          tx.type == 'earn' ||
                          tx.type == 'transfer_received' ||
                          tx.type == 'bonus',
                    )
                    .fold<int>(0, (sum, tx) => sum + tx.amount);
                final spent = transactions
                    .where(
                      (tx) => tx.type == 'spend' || tx.type == 'transfer_sent',
                    )
                    .fold<int>(0, (sum, tx) => sum + tx.amount);

                return Row(
                  children: [
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Earned',
                        amount: earned,
                        positive: true,
                        icon: LucideIcons.arrowUpRight,
                        color: FzColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Spent',
                        amount: spent,
                        positive: false,
                        icon: LucideIcons.arrowDownLeft,
                        color: FzColors.coral,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const _WalletStatsSkeleton(),
              error: (_, _) => const _WalletStatsSkeleton(),
            ),
            loading: () => const _WalletStatsSkeleton(),
            error: (_, _) => const _WalletStatsSkeleton(),
          ),
          const SizedBox(height: 24),
          const WalletFetSplitModelCard(
            isDark: true,
            muted: FzColors.darkMuted,
          ),
          const SizedBox(height: 24),
          const _HistoryHeader(),
          const SizedBox(height: 10),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const _HistoryEmptyState();
              }

              return FzCard(
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
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: WalletTransactionRow(
                          transaction: transactions[index],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => StateView.error(
              title: 'Could not load wallet history',
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
    required this.onSend,
    this.onRedeem,
  });

  final AsyncValue<int> balanceAsync;
  final String currency;
  final VoidCallback onSend;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.teal, FzColors.blue],
        ),
        borderRadius: FzRadii.heroRadius,
        boxShadow: [
          BoxShadow(
            color: FzColors.blue.withValues(alpha: 0.28),
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
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              balanceAsync.when(
                data: (balance) => Column(
                  children: [
                    FzAnimatedCounter(
                      key: const ValueKey('wallet-total-balance-value'),
                      value: balance.toDouble(),
                      style: FzTypography.score(
                        size: 42,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      formatter: (v) => formatFETCompact(v.round()),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatFET(balance, currency),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                loading: () => Text(
                  '...',
                  style: FzTypography.score(
                    size: 42,
                    weight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                error: (_, _) => Text(
                  '—',
                  style: FzTypography.score(
                    size: 42,
                    weight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroActionButton(
                          label: 'REDEEM',
                          icon: LucideIcons.gift,
                          filled: true,
                          enabled: onRedeem != null,
                          onTap: onRedeem ?? () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroActionButton(
                          label: 'SEND',
                          icon: LucideIcons.send,
                          onTap: onSend,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? Colors.white
        : Colors.white.withValues(alpha: enabled ? 0.1 : 0.05);
    final labelColor = filled ? FzColors.darkBg : Colors.white;
    final iconColor = filled ? FzColors.accent : Colors.white;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled
                ? Colors.transparent
                : Colors.white.withValues(alpha: enabled ? 0.2 : 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: labelColor.withValues(alpha: enabled ? 1 : 0.45),
              ),
            ),
          ],
        ),
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

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(LucideIcons.arrowDownLeft, size: 16, color: FzColors.darkMuted),
        SizedBox(width: 8),
        Text(
          'History',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: FzColors.darkText,
          ),
        ),
      ],
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const FzEmptyState(
      title: 'No History Yet',
      description:
          'Completed transfers, conversions, and rewards activity will appear here.',
      icon: Icon(LucideIcons.receipt, size: 24),
    );
  }
}
