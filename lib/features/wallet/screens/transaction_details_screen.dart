import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/auth_and_user/wallet.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) {
            final transaction = transactions
                .cast<WalletTransaction?>()
                .firstWhere(
                  (item) => item?.id == transactionId,
                  orElse: () => null,
                );
            if (transaction == null) {
              return StateView.empty(
                title: 'Transaction not found',
                subtitle: 'Open Wallet to choose another activity item.',
                action: () => context.go('/wallet'),
                actionLabel: 'Open Wallet',
              );
            }
            return _TransactionContent(transaction: transaction);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StateView.error(
            title: 'Could not load transaction',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(transactionServiceProvider),
          ),
        ),
      ),
    );
  }
}

class _TransactionContent extends StatelessWidget {
  const _TransactionContent({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.amount >= 0;
    final color = positive ? FzColors.success : FzColors.danger;
    final signed = positive
        ? '+${transaction.amount} FET'
        : '${transaction.amount} FET';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        FzBackHeader(
          title: 'Transaction',
          subtitle: transaction.dateStr,
          onClose: () => context.go('/wallet'),
        ),
        const SizedBox(height: 28),
        FzCard(
          padding: const EdgeInsets.all(22),
          borderRadius: FzRadii.card,
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  positive
                      ? LucideIcons.arrowUpRight
                      : LucideIcons.arrowDownLeft,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                signed,
                style: FzTypography.score(
                  size: 42,
                  color: color,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                transaction.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                transaction.type.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FzCard(
          padding: const EdgeInsets.all(16),
          borderRadius: FzRadii.card,
          child: Column(
            children: [
              const _DetailRow(label: 'Status', value: 'Settled'),
              const Divider(height: 24),
              _DetailRow(label: 'Date', value: transaction.dateStr),
              const Divider(height: 24),
              _DetailRow(label: 'Reference', value: transaction.id),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
