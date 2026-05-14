import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/hospitality/order_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/order_provider.dart';

class OrderReceiptScreen extends ConsumerWidget {
  const OrderReceiptScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      body: SafeArea(
        child: orderAsync.when(
          data: (order) {
            if (order == null) {
              return StateView.empty(
                title: 'Receipt not found',
                subtitle: 'Open Orders to choose another receipt.',
                action: () => context.go('/orders'),
                actionLabel: 'Open Orders',
              );
            }
            return _ReceiptContent(order: order);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StateView.error(
            title: 'Could not load receipt',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
          ),
        ),
      ),
    );
  }
}

class _ReceiptContent extends StatelessWidget {
  const _ReceiptContent({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        FzBackHeader(
          title: 'Order #${order.orderCode}',
          subtitle: 'Receipt detail',
          onClose: () => context.go('/orders'),
        ),
        const SizedBox(height: 24),
        FzCard(
          padding: const EdgeInsets.all(20),
          borderRadius: FzRadii.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: FzColors.success.withValues(alpha: 0.13),
                      borderRadius: FzRadii.compactRadius,
                    ),
                    child: const Icon(
                      LucideIcons.badgeCheck,
                      color: FzColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.paymentStatus.label,
                          style: FzTypography.display(
                            size: 26,
                            color: FzColors.darkText,
                          ),
                        ),
                        Text(
                          '${order.paymentMethod.label} · ${order.status.label}',
                          style: const TextStyle(
                            color: FzColors.darkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FzMetricTile(
                label: 'Total',
                value: order.totalDisplay,
                color: FzColors.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FzSectionHeader(title: 'Items'),
        const SizedBox(height: 10),
        FzCard(
          padding: const EdgeInsets.all(16),
          borderRadius: FzRadii.card,
          child: Column(
            children: [
              for (final item in order.items ?? const <OrderItemModel>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: FzColors.accent.withValues(alpha: 0.12),
                          borderRadius: FzRadii.buttonRadius,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            color: FzColors.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.itemNameSnapshot,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        item.lineTotalDisplay,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              _ReceiptRow(
                label: 'Subtotal',
                value: _amount(order, order.subtotalAmount),
              ),
              const SizedBox(height: 8),
              _ReceiptRow(label: 'Tip', value: _amount(order, order.tipAmount)),
              const SizedBox(height: 8),
              _ReceiptRow(
                label: 'Total',
                value: order.totalDisplay,
                strong: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _amount(OrderModel order, double amount) {
    if (order.currencyCode == 'EUR') return '€${amount.toStringAsFixed(2)}';
    if (order.currencyCode == 'RWF') return 'RWF ${amount.toStringAsFixed(0)}';
    return '${order.currencyCode} ${amount.toStringAsFixed(2)}';
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? FzColors.darkText : FzColors.darkMuted,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 18 : 14,
            fontWeight: FontWeight.w900,
            color: strong ? FzColors.accent : FzColors.darkText,
          ),
        ),
      ],
    );
  }
}
