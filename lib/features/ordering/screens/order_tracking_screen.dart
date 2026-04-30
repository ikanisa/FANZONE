import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/order_provider.dart';
import '../../../models/hospitality/order_model.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(LucideIcons.x),
        ),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return StateView.empty(
              title: 'Order not found',
              subtitle: 'We couldn\'t find that order record.',
            );
          }
          return _TrackingContent(order: order);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StateView.error(subtitle: e.toString()),
      ),
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _StatusTimeline(status: order.status),
        const SizedBox(height: 40),
        const Text('ORDER DETAILS',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${order.orderCode}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const Divider(height: 32),
              ...order.items
                      ?.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: FzColors.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                      child: Text('${item.quantity}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: FzColors.accent))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(item.itemNameSnapshot,
                                        style: const TextStyle(fontSize: 15))),
                                Text(item.lineTotalDisplay,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ))
                      .toList() ??
                  [],
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Paid',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(order.totalDisplay,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: FzColors.accent)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimelineItem(
          label: 'Order Placed',
          subtitle: 'Your order has been sent to the kitchen',
          icon: LucideIcons.checkCircle2,
          isActive: true,
          isCompleted: status != OrderStatus.placed,
        ),
        _TimelineConnector(isActive: status != OrderStatus.placed),
        _TimelineItem(
          label: 'Preparing',
          subtitle: 'The chef is preparing your meal',
          icon: LucideIcons.utensils,
          isActive:
              status == OrderStatus.received || status == OrderStatus.served,
          isCompleted: status == OrderStatus.served,
        ),
        _TimelineConnector(isActive: status == OrderStatus.served),
        _TimelineItem(
          label: 'Served',
          subtitle: 'Your order has arrived at your table',
          icon: LucideIcons.partyPopper,
          isActive: status == OrderStatus.served,
          isCompleted: status == OrderStatus.served,
          isLast: true,
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.isCompleted,
    this.isLast = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isCompleted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? FzColors.success
        : (isActive ? FzColors.accent : FzColors.lightMuted);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(isCompleted ? LucideIcons.check : icon,
                  color: color, size: 20),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isActive ? null : FzColors.lightMuted)),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 13, color: FzColors.lightMuted)),
              if (!isLast) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 30,
      alignment: Alignment.center,
      child: Container(
        width: 2,
        height: 30,
        color: isActive ? FzColors.success : FzColors.lightBorder,
      ),
    );
  }
}
