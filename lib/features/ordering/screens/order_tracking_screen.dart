import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/design_system.dart';
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
                  const FzBackHeader(title: 'Order'),
                  const SizedBox(height: 48),
                  StateView.empty(
                    title: 'Order not found',
                    subtitle: 'Not found.',
                    icon: LucideIcons.receipt,
                    action: () => context.go('/orders'),
                    actionLabel: 'Orders',
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
              const FzBackHeader(title: 'Order'),
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

class _TrackingContent extends ConsumerWidget {
  const _TrackingContent({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        const FzBackHeader(title: 'Order'),
        const SizedBox(height: 18),
        _StatusTimeline(status: order.status),
        const SizedBox(height: 18),
        _PaymentStatusCard(order: order),
        const SizedBox(height: 28),
        Text('DETAILS', style: AppTypography.status(color: AppColors.muted)),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${order.orderCode}', style: AppTypography.cardTitle),
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
                                    style: AppTypography.label.copyWith(
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
                                  style: AppTypography.body.copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                item.lineTotalDisplay,
                                style: AppTypography.label,
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
                  const Text('Total', style: AppTypography.label),
                  Text(
                    order.totalDisplay,
                    style: AppTypography.cardTitle.copyWith(
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
        AppButton(
          onPressed: () => context.push('/order/${order.id}/receipt'),
          icon: LucideIcons.receipt,
          label: 'Receipt',
          variant: AppButtonVariant.secondary,
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
          FzBackHeader(title: 'Order'),
          Expanded(child: Center(child: CircularProgressIndicator())),
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
          subtitle: '',
          icon: LucideIcons.checkCircle2,
          isActive: true,
          isCompleted: status.isAcceptedOrLater,
        ),
        _TimelineConnector(isActive: status.isPreparingOrLater),
        _TimelineItem(
          label: 'Preparing',
          subtitle: '',
          icon: LucideIcons.loader,
          isActive: status == OrderStatus.preparing,
          isCompleted: status.isPreparingOrLater,
        ),
        _TimelineConnector(isActive: status.isReadyOrLater),
        _TimelineItem(
          label: 'Ready',
          subtitle: '',
          icon: LucideIcons.bell,
          isActive: status == OrderStatus.ready,
          isCompleted: status.isReadyOrLater,
        ),
        _TimelineConnector(isActive: status.isServedOrLater),
        _TimelineItem(
          label: 'Served',
          subtitle: '',
          icon: LucideIcons.badgeCheck,
          isActive: status == OrderStatus.served,
          isCompleted: status.isServedOrLater,
          isLast: !{
            OrderStatus.cancelled,
            OrderStatus.refunded,
            OrderStatus.disputed,
          }.contains(status),
        ),
        if ({
          OrderStatus.cancelled,
          OrderStatus.refunded,
          OrderStatus.disputed,
        }.contains(status)) ...[
          const _TimelineConnector(isActive: true),
          _TimelineItem(
            label: status.label,
            subtitle: '',
            icon: status == OrderStatus.disputed
                ? LucideIcons.alertTriangle
                : LucideIcons.xCircle,
            isActive: true,
            isCompleted: true,
            isLast: true,
          ),
        ],
      ],
    );
  }
}

class _PaymentStatusCard extends ConsumerStatefulWidget {
  const _PaymentStatusCard({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_PaymentStatusCard> createState() => _PaymentStatusCardState();
}

class _PaymentStatusCardState extends ConsumerState<_PaymentStatusCard> {
  bool _submitting = false;

  Future<void> _submitPayment() async {
    setState(() => _submitting = true);
    try {
      await submitPaymentForOrder(ref, widget.order);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Awaiting venue.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment submission failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order.paymentStatus;
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
    final canSubmit = canSubmitPaymentForOrder(widget.order);

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.creditCard, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment',
                      style: AppTypography.status(color: AppColors.muted),
                    ),
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      status.label,
                      style: AppTypography.cardTitle.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              AppStatusPill(status: status.name, label: 'Manual'),
            ],
          ),
          if (canSubmit) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitPayment,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.checkCircle2, size: 16),
                label: const Text('I paid'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ] else if (status == PaymentStatus.paymentSubmitted) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Awaiting venue.',
              style: AppTypography.secondary.copyWith(color: AppColors.muted),
            ),
          ] else if (status == PaymentStatus.paid) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Paid.',
              style: AppTypography.secondary.copyWith(color: AppColors.muted),
            ),
          ],
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
              if (subtitle.isNotEmpty)
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
