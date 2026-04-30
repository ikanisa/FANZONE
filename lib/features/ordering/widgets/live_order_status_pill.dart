import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../providers/order_provider.dart';
import '../../../models/hospitality/order_model.dart';

class LiveOrderStatusPill extends ConsumerWidget {
  const LiveOrderStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrdersAsync = ref.watch(activeOrdersProvider);

    return activeOrdersAsync.when(
      data: (orders) {
        if (orders.isEmpty) return const SizedBox.shrink();

        final latestOrder = orders.first;
        return _PillContent(order: latestOrder);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PillContent extends StatelessWidget {
  const _PillContent({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: FzColors.darkBg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: FzColors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTrackingSheet(context, order.id),
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusIcon(status: order.status),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER STATUS',
                      style: FzTypography.metaLabel(color: FzColors.accent).copyWith(fontSize: 10),
                    ),
                    Text(
                      _statusText(order.status),
                      style: const TextStyle(
                        color: FzColors.darkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                const Icon(LucideIcons.chevronUp, color: FzColors.darkMuted, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return 'Sent to Kitchen';
      case OrderStatus.received:
        return 'Preparing Now';
      case OrderStatus.served:
        return 'Enjoy your meal!';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  void _showTrackingSheet(BuildContext context, String orderId) {
    // We can navigate or show a bottom sheet here
    context.push('/order-tracking/$orderId');
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final bool isSpinning = status == OrderStatus.received;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: FzColors.accent.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: isSpinning
          ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(FzColors.accent),
              ),
            )
          : const Icon(LucideIcons.utensils, color: FzColors.accent, size: 16),
    );
  }
}
