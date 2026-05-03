import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_animated_counter.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../../services/wallet_service.dart';
import '../data/wallet_gateway.dart';
import '../widgets/wallet_screen_components.dart';
import '../widgets/wallet_transfer_sheets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

/// Wallet screen aligned to the primary reference wallet hub.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletBalanceAsync = ref.watch(walletBalanceProvider);
    final transactionsAsync = ref.watch(transactionServiceProvider);
    final isVerified = ref.watch(isFullyAuthenticatedProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final transactions = transactionsAsync.valueOrNull ?? const [];
    final orderEarned = transactions
        .where((tx) => tx.type == 'order_earn')
        .fold<int>(0, (sum, tx) => sum + tx.amount);
    final poolEarned = transactions
        .where((tx) => tx.type == 'pool_win' || tx.type == 'creator_reward')
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          const FzReferenceHeader(title: 'Sports Elite'),
          const SizedBox(height: 24),
          Text(
            'Wallet',
            style: FzTypography.display(
              size: 38,
              color: FzColors.darkText,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your FET balance, locked stakes, rewards, and activity.',
            style: TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _WalletHero(
            balanceAsync: walletBalanceAsync,
            currency: currency,
            onSend: () {
              if (!isVerified) {
                showSignInRequiredSheet(
                  context,
                  title: 'Verify WhatsApp to transfer FET',
                  message:
                      'Verify your WhatsApp number before sending FET to another fan.',
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
                        color: FzColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Staked',
                        amount: balance.stakedFet,
                        positive: true,
                        showSign: false,
                        icon: LucideIcons.lock,
                        color: FzColors.primary,
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
                        color: FzColors.coral,
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
                        color: FzColors.accent2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Order Earned',
                        amount: orderEarned,
                        positive: true,
                        icon: LucideIcons.utensils,
                        color: FzColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WalletSummaryCard(
                        label: 'Pool Earned',
                        amount: poolEarned,
                        positive: true,
                        icon: LucideIcons.trophy,
                        color: FzColors.accent2,
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
          const SizedBox(height: 24),
          const FzCard(
            child: Row(
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  size: 18,
                  color: FzColors.success,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Wallet activity covers bar-order rewards, FET spent on orders, pool stakes, and audited settlements.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: FzColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _HowToEarnFetCard(
            onOpenVenues: () => context.go('/venues'),
            onOpenArena: () => context.go('/pools'),
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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
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
  });

  final AsyncValue<WalletBalance> balanceAsync;
  final String currency;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.teal, FzColors.accent2],
        ),
        borderRadius: FzRadii.heroRadius,
        boxShadow: [
          BoxShadow(
            color: FzColors.accent2.withValues(alpha: 0.30),
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
                'FET BALANCE',
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
                      value: balance.availableFet.toDouble(),
                      style: FzTypography.score(
                        size: 42,
                        weight: FontWeight.w700,
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
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: _HeroActionButton(
                    label: 'Send FET',
                    icon: LucideIcons.send,
                    filled: true,
                    onTap: onSend,
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
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.1);
    final labelColor = filled ? FzColors.darkBg : Colors.white;
    final iconColor = filled ? FzColors.primary : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToEarnFetCard extends StatelessWidget {
  const _HowToEarnFetCard({
    required this.onOpenVenues,
    required this.onOpenArena,
  });

  final VoidCallback onOpenVenues;
  final VoidCallback onOpenArena;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.sparkles, size: 18, color: FzColors.success),
              SizedBox(width: 10),
              Text(
                'How to Earn FET',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _EarnStep(
            icon: LucideIcons.utensils,
            title: 'Order at venues',
            subtitle: 'Earn rewards after venue staff confirm payment.',
          ),
          const SizedBox(height: 10),
          const _EarnStep(
            icon: LucideIcons.trophy,
            title: 'Enter Arena pools',
            subtitle: 'Stake FET and receive audited settlement rewards.',
          ),
          const SizedBox(height: 10),
          const _EarnStep(
            icon: LucideIcons.send,
            title: 'Invite friends',
            subtitle: 'Share pool links and keep activity inside FANZONE.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenVenues,
                  icon: const Icon(LucideIcons.store, size: 16),
                  label: const Text('Venues'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenArena,
                  icon: const Icon(LucideIcons.trophy, size: 16),
                  label: const Text('Arena'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarnStep extends StatelessWidget {
  const _EarnStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: FzColors.darkSurface2,
            borderRadius: FzRadii.buttonRadius,
            border: Border.all(color: FzColors.darkBorder),
          ),
          child: Icon(icon, size: 17, color: FzColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: FzColors.darkText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: FzColors.darkMuted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

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
              color: FzColors.accent2,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wallet totals are unavailable right now.',
                style: TextStyle(fontSize: 11, color: muted, height: 1.4),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: FzColors.primary,
                side: BorderSide(color: border),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 6),
          const Text(
            'Unavailable',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FzColors.accent2,
            ),
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
          'Order rewards, pool stakes, settlement wins, and FET spending will appear here.',
      icon: Icon(LucideIcons.receipt, size: 24),
    );
  }
}
