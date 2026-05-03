import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/order_provider.dart';
import '../../../models/hospitality/order_model.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderRealtimeProvider(orderId));

    return Scaffold(
      body: SafeArea(
        child: orderAsync.when(
          data: (order) {
            if (order == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                children: [
                  const FzBackHeader(
                    title: 'Order Status',
                    subtitle: 'Venue confirmation and FET reward',
                  ),
                  const SizedBox(height: 48),
                  StateView.empty(
                    title: 'Order not found',
                    subtitle: 'We couldn\'t find that order record.',
                    icon: LucideIcons.receipt,
                    action: () => context.go('/orders'),
                    actionLabel: 'Open Orders',
                  ),
                ],
              );
            }
            return _TrackingContent(order: order);
          },
          loading: () => const _OrderTrackingLoadingState(),
          error: (e, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              const FzBackHeader(
                title: 'Order Status',
                subtitle: 'Venue confirmation and FET reward',
              ),
              const SizedBox(height: 48),
              StateView.error(
                subtitle: e.toString(),
                onRetry: () => ref.invalidate(orderRealtimeProvider(orderId)),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        const FzBackHeader(
          title: 'Order Status',
          subtitle: 'Venue confirmation and FET reward',
        ),
        const SizedBox(height: 18),
        _FetEarnedCard(order: order),
        const SizedBox(height: 18),
        _StatusTimeline(status: order.status),
        const SizedBox(height: 18),
        _PaymentStatusCard(status: order.paymentStatus),
        const SizedBox(height: 28),
        const Text(
          'ORDER DETAILS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
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
              const Divider(height: 32),
              ...order.items
                      ?.map(
                        (item) => Padding(
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
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: FzColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.itemNameSnapshot,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              Text(
                                item.lineTotalDisplay,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList() ??
                  [],
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    order.totalDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: FzColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => context.push('/order/${order.id}/receipt'),
          icon: const Icon(LucideIcons.receipt, size: 16),
          label: const Text('View Receipt'),
        ),
      ],
    );
  }
}

class _OrderTrackingLoadingState extends StatelessWidget {
  const _OrderTrackingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          FzBackHeader(
            title: 'Order Status',
            subtitle: 'Venue confirmation and FET reward',
          ),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _FetEarnedCard extends StatelessWidget {
  const _FetEarnedCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.coins, color: FzColors.success),
              SizedBox(width: 10),
              Text(
                'FET Earned',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '+${order.earnedFetDisplayAmount} FET',
            style: const TextStyle(
              color: FzColors.success,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.paymentStatus.isPaid
                ? (order.earnedFetDisplayAmount > 0
                      ? 'Credited through the wallet ledger.'
                      : 'No FET reward is configured for this order.')
                : 'Pending until venue staff confirm payment.',
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
          label: 'Received',
          subtitle: 'The venue has the order request',
          icon: LucideIcons.checkCircle2,
          isActive: true,
          isCompleted:
              status == OrderStatus.received ||
              status == OrderStatus.preparing ||
              status == OrderStatus.served,
        ),
        _TimelineConnector(
          isActive:
              status == OrderStatus.preparing || status == OrderStatus.served,
        ),
        _TimelineItem(
          label: 'Preparing',
          subtitle: 'The kitchen is preparing your order',
          icon: LucideIcons.loader,
          isActive: status == OrderStatus.preparing,
          isCompleted:
              status == OrderStatus.preparing || status == OrderStatus.served,
        ),
        _TimelineConnector(isActive: status == OrderStatus.served),
        _TimelineItem(
          label: 'Served',
          subtitle: 'Venue staff marked the order served',
          icon: LucideIcons.badgeCheck,
          isActive: status == OrderStatus.served,
          isCompleted: status == OrderStatus.served,
          isLast: status != OrderStatus.cancelled,
        ),
        if (status == OrderStatus.cancelled) ...[
          const _TimelineConnector(isActive: true),
          const _TimelineItem(
            label: 'Cancelled',
            subtitle: 'The venue cancelled this order',
            icon: LucideIcons.xCircle,
            isActive: true,
            isCompleted: true,
            isLast: true,
          ),
        ],
      ],
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PaymentStatus.paid => FzColors.success,
      PaymentStatus.paymentSubmitted => FzColors.warning,
      PaymentStatus.partiallyPaid => FzColors.warning,
      PaymentStatus.refunded => FzColors.accent2,
      PaymentStatus.disputed || PaymentStatus.failed => FzColors.danger,
      PaymentStatus.pending ||
      PaymentStatus.unpaid ||
      PaymentStatus.cancelled => FzColors.darkMuted,
    };

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(LucideIcons.creditCard, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment status',
                  style: TextStyle(fontSize: 12, color: FzColors.darkMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 18,
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Manual confirmation',
            style: TextStyle(fontSize: 12, color: FzColors.darkMuted),
          ),
        ],
      ),
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
              child: Icon(
                isCompleted ? LucideIcons.check : icon,
                color: color,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isActive ? null : FzColors.lightMuted,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: FzColors.lightMuted,
                ),
              ),
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
