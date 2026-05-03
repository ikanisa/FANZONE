import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/hospitality/order_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/order_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(orderHistoryProvider);
            await ref.read(orderHistoryProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              const FzReferenceHeader(title: 'Sports Elite'),
              const SizedBox(height: 24),
              Text(
                'Orders',
                style: FzTypography.display(size: 38, color: FzColors.darkText),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track venue orders, payment confirmation, receipts, and FET impact.',
                style: TextStyle(
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ordersAsync.when(
                data: (orders) {
                  if (orders.isEmpty) {
                    return FzEmptyState(
                      title: 'No orders yet',
                      description:
                          'Open a venue menu and place an order to start earning FET.',
                      icon: const Icon(LucideIcons.receipt),
                      actionLabel: 'Browse Venues',
                      onAction: () => context.go('/venues'),
                    );
                  }

                  final active = orders.where((order) => order.status.isActive);
                  final past = orders.where((order) => !order.status.isActive);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (active.isNotEmpty) ...[
                        const FzSectionHeader(title: 'Active'),
                        const SizedBox(height: 10),
                        for (final order in active)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OrderCard(order: order),
                          ),
                        const SizedBox(height: 8),
                      ],
                      const FzSectionHeader(title: 'Recent'),
                      const SizedBox(height: 10),
                      for (final order in past.isEmpty ? orders : past)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OrderCard(order: order),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => StateView.error(
                  title: 'Could not load orders',
                  subtitle: error.toString(),
                  onRetry: () => ref.invalidate(orderHistoryProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      OrderStatus.served => FzColors.success,
      OrderStatus.cancelled => FzColors.danger,
      OrderStatus.preparing => FzColors.warning,
      OrderStatus.received => FzColors.accent,
      OrderStatus.placed => FzColors.accent3,
    };

    return FzCard(
      onTap: () => context.push('/order/${order.id}'),
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: FzRadii.compactRadius,
                ),
                child: Icon(LucideIcons.receipt, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderCode}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.itemCount} items · ${order.paymentMethod.label}',
                      style: const TextStyle(
                        color: FzColors.darkMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                order.totalDisplay,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FzMetricTile(
                  label: 'Status',
                  value: order.status.label,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FzMetricTile(
                  label: 'FET Earned',
                  value: '+${order.earnedFetDisplayAmount}',
                  color: FzColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
