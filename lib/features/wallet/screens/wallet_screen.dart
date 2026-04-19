import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_config.dart';
import '../../../core/market/launch_market.dart';
import '../../../core/utils/currency_utils.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../services/wallet_service.dart';
import '../../../models/wallet.dart';
import '../../../services/team_community_service.dart';

/// Wallet screen — FET balance, transaction history, transfer/receive actions.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletServiceProvider);
    final transactionsAsync = ref.watch(transactionServiceProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final primaryRegion = ref.watch(primaryMarketRegionProvider);
    final focusTags = ref.watch(marketFocusTagsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BALANCES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Wallet Hub',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? FzColors.darkText : FzColors.lightText,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),

          // Balance card
          FzCard(
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [FzColors.teal, FzColors.blue],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Balance',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  balanceAsync.when(
                    data: (balance) => TweenAnimationBuilder<int>(
                      key: ValueKey('balance_$balance'),
                      tween: IntTween(begin: balance, end: balance),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final currency =
                            ref.watch(userCurrencyProvider).valueOrNull ??
                            'EUR';
                        return Column(
                          children: [
                            Text(
                              formatFET(value, currency),
                              style: FzTypography.score(
                                size: 28,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    loading: () => Text(
                      '...',
                      style: FzTypography.score(
                        size: 40,
                        weight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                    error: (_, st) => Text(
                      '—',
                      style: FzTypography.score(
                        size: 40,
                        weight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fan Engagement Tokens',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _WalletMetaChip(
                        label: '${supportedIds.length} clubs linked',
                      ),
                      _WalletMetaChip(
                        label: fanId != null ? 'Fan #$fanId' : 'Fan ID pending',
                      ),
                      const _WalletMetaChip(label: 'Pools + support ready'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _WalletActionButton(
                        icon: LucideIcons.arrowDownLeft,
                        label: 'Receive',
                        onTap: () {
                          if (!isAuthenticated) {
                            showSignInRequiredSheet(
                              context,
                              title: 'Sign in to get your Fan ID',
                              message:
                                  'Phone verification is only required when you want to receive FET or share your Fan ID.',
                              from: '/wallet',
                            );
                            return;
                          }

                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const _ReceiveFetSheet(),
                          );
                        },
                      ),
                      _WalletActionButton(
                        icon: LucideIcons.send,
                        label: 'Send FET',
                        onTap: () {
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
                            builder: (_) => const _TransferFetSheet(),
                          );
                        },
                      ),
                      if (AppConfig.enableRewards ||
                          AppConfig.enableMarketplace)
                        _WalletActionButton(
                          icon: LucideIcons.gift,
                          label: 'Redeem',
                          onTap: () => context.push('/wallet/rewards'),
                        ),
                      _WalletActionButton(
                        icon: LucideIcons.arrowUpRight,
                        label: 'Exchange',
                        onTap: () => context.push('/wallet/exchange'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          transactionsAsync.when(
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
                    child: _WalletSummaryCard(
                      label: 'Earned',
                      amount: earned,
                      positive: true,
                      icon: LucideIcons.arrowUpRight,
                      color: FzColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WalletSummaryCard(
                      label: 'Spent',
                      amount: spent,
                      positive: false,
                      icon: LucideIcons.arrowDownLeft,
                      color: FzColors.violet,
                    ),
                  ),
                ],
              );
            },
            loading: () => const FzCard(
              padding: EdgeInsets.all(16),
              child: Text('Loading wallet totals...'),
            ),
            error: (_, _) => FzCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Wallet totals are unavailable right now.'),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(transactionServiceProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          FzCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: FzColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.shieldCheck,
                        size: 16,
                        color: FzColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your wallet powers three FANZONE loops.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? FzColors.darkText
                              : FzColors.lightText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Enter pools and challenges.\n2. Support clubs through FET.\n3. Transfer and receive using Fan ID.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.45),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          FzCard(
            padding: const EdgeInsets.all(16),
            borderColor: FzColors.accent.withValues(alpha: 0.22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GLOBAL UTILITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'FET now needs to work across ${launchRegionLabel(primaryRegion).toLowerCase()} and the wider football cycle. Free challenges can onboard users first, while Fan ID, club support, and redemptions remain the durable utility layer.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.45),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WalletMetaChip(
                      label: '${launchRegionLabel(primaryRegion)} first',
                    ),
                    for (final tag
                        in (focusTags.isEmpty
                                ? defaultFocusTagsForRegion(primaryRegion)
                                : focusTags.toList())
                            .take(2))
                      _WalletMetaChip(
                        label: launchMomentByTag(tag)?.title ?? tag,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── FET Split Model (from original design reference) ──
          Text(
            'FET SPLIT MODEL',
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
                  'Pool winnings are split between your wallet and your fan club pool based on membership tier.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Wallet (80%)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? FzColors.darkText
                                : FzColors.lightText,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Text(
                          'Club Pool (20%)',
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
                              child: Container(color: FzColors.violet),
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
                      'Current split model shown for an Ultra-style supporter tier.',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FetSplitRow(
                  tier: 'Supporter',
                  walletPct: 100,
                  clubPct: 0,
                  isActive: true,
                  muted: muted,
                ),
                const SizedBox(height: 8),
                _FetSplitRow(
                  tier: 'Member',
                  walletPct: 90,
                  clubPct: 10,
                  isActive: false,
                  muted: muted,
                ),
                const SizedBox(height: 8),
                _FetSplitRow(
                  tier: 'Ultra',
                  walletPct: 80,
                  clubPct: 20,
                  isActive: false,
                  muted: muted,
                ),
                const SizedBox(height: 8),
                _FetSplitRow(
                  tier: 'Legend',
                  walletPct: 65,
                  clubPct: 35,
                  isActive: false,
                  muted: muted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Transaction history
          Text(
            'TRANSACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: StateView.empty(
                    title: 'No transactions yet',
                    subtitle: 'Your activity will appear here.',
                    icon: LucideIcons.receipt,
                  ),
                );
              }
              return Column(
                children: transactions.map(_buildTransactionRow).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, st) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: StateView.error(
                title: 'Could not load transactions',
                onRetry: () => ref.invalidate(transactionServiceProvider),
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(WalletTransaction tx) {
    final isEarn =
        tx.type == 'earn' ||
        tx.type == 'transfer_received' ||
        tx.type == 'bonus';
    final color = isEarn ? FzColors.success : FzColors.danger;
    final icon = _iconForType(tx.type);
    final prefix = isEarn ? '+' : '-';

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

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
                      tx.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      tx.dateStr,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final currency =
                      ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
                  return Text(
                    '$prefix ${formatFET(tx.amount, currency)}',
                    style: FzTypography.scoreCompact(color: color),
                  );
                },
              ),
            ],
          ),
        );
      },
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

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
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

class _WalletSummaryCard extends ConsumerWidget {
  const _WalletSummaryCard({
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

class _WalletMetaChip extends StatelessWidget {
  const _WalletMetaChip({required this.label});

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

class _TransferFetSheet extends ConsumerStatefulWidget {
  const _TransferFetSheet();

  @override
  ConsumerState<_TransferFetSheet> createState() => _TransferFetSheetState();
}

class _TransferFetSheetState extends ConsumerState<_TransferFetSheet> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isValidFanId {
    final text = _recipientController.text.trim();
    return RegExp(r'^\d{6}$').hasMatch(text);
  }

  Future<void> _submit() async {
    final fanId = _recipientController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;

    if (!_isValidFanId) {
      setState(() => _error = 'Enter a valid 6-digit Fan ID.');
      return;
    }

    if (amount <= 0) {
      setState(() => _error = 'Enter a valid FET amount.');
      return;
    }

    // Self-transfer check
    final myFanId = ref.read(userFanIdProvider).valueOrNull;
    if (myFanId != null && myFanId == fanId) {
      setState(() => _error = 'You cannot transfer tokens to yourself.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(walletServiceProvider.notifier)
          .transferByFanId(fanId, amount);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You successfully sent $amount FET to Fan #$fanId'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final balance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Send FET',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Transfer tokens using the recipient\'s 6-digit Fan ID.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _recipientController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Recipient Fan ID',
                  hintText: '000000',
                  counterText: '',
                  prefixIcon: Icon(LucideIcons.hash, size: 18, color: muted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Amount (FET)',
                  hintText: '0',
                  helperText: 'Available: ${formatFET(balance, currency)}',
                  prefixIcon: Icon(LucideIcons.wallet, size: 18, color: muted),
                ),
              ),
              if ((_error ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FzColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 16,
                        color: FzColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FzColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_submitting || !_isValidFanId) ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.send, size: 16),
                  label: Text(_submitting ? 'Sending...' : 'Send FET'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiveFetSheet extends ConsumerWidget {
  const _ReceiveFetSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final shareText = fanId != null
        ? 'Send FET to Fan #$fanId on FANZONE.'
        : 'Find me on FANZONE and send FET using my Fan ID.';
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Receive FET',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share your Fan ID so other fans can send you tokens.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 18),
              FzCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      fanId != null ? 'Fan #$fanId' : 'FANZONE Member',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your Fan ID',
                      style: TextStyle(
                        fontSize: 11,
                        color: muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: FzColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: FzColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        fanId != null ? '#$fanId' : 'Loading...',
                        style: FzTypography.score(
                          size: 28,
                          weight: FontWeight.w700,
                          color: FzColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Others can send FET to you using this 6-digit Fan ID.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: fanId == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: fanId),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fan ID copied.')),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await SharePlus.instance.share(
                          ShareParams(text: shareText),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FetSplitRow extends StatelessWidget {
  const _FetSplitRow({
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

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Row(
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
              Text(
                tier,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? FzColors.accent : muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
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
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '$walletPct / $clubPct',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
