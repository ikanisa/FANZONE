import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../models/hospitality/order_model.dart';
import '../providers/order_provider.dart';

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
          children: [
            FzBackHeader(
              title: 'Order Received',
              subtitle: 'Venue confirmation pending',
              onClose: () => context.go('/orders'),
            ),
            const SizedBox(height: 18),
            orderAsync.when(
              data: (order) => _SuccessHero(
                earnedFet: order?.earnedFetDisplayAmount,
                totalDisplay: order?.totalDisplay,
              ),
              loading: () => const _SuccessHero(),
              error: (_, _) => const _SuccessHero(),
            ),
            const SizedBox(height: 18),
            orderAsync.when(
              data: (order) {
                if (order == null) {
                  return const FzCard(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Order details are syncing. You can still open Orders to track status.',
                    ),
                  );
                }
                return _OrderSummaryCard(order: order);
              },
              loading: () => const FzCard(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Loading order details...'),
                  ],
                ),
              ),
              error: (error, _) => FzCard(
                padding: const EdgeInsets.all(16),
                child: Text('Order details are unavailable: $error'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/order/$orderId'),
              icon: const Icon(LucideIcons.mapPin, size: 16),
              label: const Text('Track Order'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/order/$orderId/receipt'),
                    icon: const Icon(LucideIcons.receipt, size: 16),
                    label: const Text('Receipt'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/venues'),
                    icon: const Icon(LucideIcons.store, size: 16),
                    label: const Text('Venues'),
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

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({this.earnedFet, this.totalDisplay});

  final int? earnedFet;
  final String? totalDisplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.primary, FzColors.teal],
          stops: [0, 0.58, 1],
        ),
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: FzColors.primary.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: FzRadii.compactRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              LucideIcons.checkCircle2,
              size: 30,
              color: FzColors.success,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Order sent to venue',
            style: FzTypography.display(
              size: 32,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payment stays pending until staff confirm. Your FET reward posts through the wallet ledger after confirmation.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Reward',
                  value: earnedFet == null || earnedFet == 0
                      ? 'Pending'
                      : '+$earnedFet FET',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Total',
                  value: totalDisplay ?? 'Pending',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FzColors.primary.withValues(alpha: 0.12),
                  borderRadius: FzRadii.buttonRadius,
                ),
                child: const Icon(LucideIcons.receipt, color: FzColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.paymentMethod.label} - ${order.paymentStatus.label}',
                      style: const TextStyle(
                        color: FzColors.darkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _SummaryRow(label: 'Total', value: order.totalDisplay),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'FET reward',
            value: '+${order.earnedFetDisplayAmount} FET',
            valueColor: FzColors.success,
          ),
          if (order.paymentFetAmount > 0) ...[
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'FET spent',
              value: '${order.paymentFetAmount} FET',
              valueColor: FzColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: FzRadii.buttonRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = FzColors.darkText,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
