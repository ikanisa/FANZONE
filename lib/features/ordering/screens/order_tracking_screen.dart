import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/gateway_providers.dart';
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
        const SizedBox(height: 12),
        _OrderIssueCard(order: order),
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
    final isSubmitted =
        status == OrderStatus.placed || status == OrderStatus.submitted;
    final isAccepted =
        status == OrderStatus.received || status == OrderStatus.accepted;
    final isCompleted = status == OrderStatus.completed;
    final isException = {
      OrderStatus.cancelled,
      OrderStatus.refunded,
      OrderStatus.disputed,
    }.contains(status);

    return Column(
      children: [
        _TimelineItem(
          label: 'Submitted',
          subtitle: '',
          icon: LucideIcons.checkCircle2,
          isActive: isSubmitted,
          isCompleted: status.isAcceptedOrLater || isCompleted || isException,
        ),
        _TimelineConnector(isActive: status.isAcceptedOrLater),
        _TimelineItem(
          label: 'Accepted',
          subtitle: '',
          icon: LucideIcons.clipboardCheck,
          isActive: isAccepted,
          isCompleted: status.isPreparingOrLater || isCompleted,
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
        ),
        _TimelineConnector(isActive: isCompleted),
        _TimelineItem(
          label: 'Completed',
          subtitle: '',
          icon: LucideIcons.partyPopper,
          isActive: isCompleted,
          isCompleted: isCompleted,
          isLast: !isException,
        ),
        if (isException) ...[
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

  String get _submitLabel {
    return widget.order.paymentStatus == PaymentStatus.failed
        ? 'Send updated proof'
        : 'I paid';
  }

  Future<void> _submitPayment() async {
    final proof = await _showPaymentProofSheet(context, widget.order);
    if (proof == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await submitPaymentForOrder(
        ref,
        widget.order,
        externalReference: proof.externalReference,
        note: proof.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment proof sent.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send payment proof. Try again.'),
        ),
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
            if (status == PaymentStatus.failed) ...[
              Text(
                'Payment was not verified. Send updated proof or ask venue staff.',
                style: AppTypography.secondary.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
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
                label: Text(_submitLabel),
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
          ] else if (status == PaymentStatus.failed) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Payment was not verified. Send updated proof or ask venue staff.',
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

class _PaymentProofDraft {
  const _PaymentProofDraft({this.externalReference, this.note});

  final String? externalReference;
  final String? note;
}

Future<_PaymentProofDraft?> _showPaymentProofSheet(
  BuildContext context,
  OrderModel order,
) {
  final referenceController = TextEditingController();
  final noteController = TextEditingController();

  return showModalBottomSheet<_PaymentProofDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
      final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: FzColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    LucideIcons.receiptText,
                    color: FzColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment proof',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${order.paymentMethod.label} - staff confirms payment.',
                        style: TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('payment_proof_reference'),
              controller: referenceController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.hash),
                labelText: 'Reference optional',
                hintText: 'MoMo code or Revolut note',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('payment_proof_note'),
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.messageSquare),
                labelText: 'Note optional',
                hintText: 'Anything staff should verify',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This does not mark the order paid. Venue staff still confirm it.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('payment_proof_submit'),
              onPressed: () {
                Navigator.of(sheetContext).pop(
                  _PaymentProofDraft(
                    externalReference: normalizePaymentProofText(
                      referenceController.text,
                    ),
                    note: normalizePaymentProofText(noteController.text),
                  ),
                );
              },
              icon: const Icon(LucideIcons.send, size: 17),
              label: const Text('Send proof'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(() {
    _disposeControllersAfterRouteRemoval([referenceController, noteController]);
  });
}

class _OrderIssueCard extends ConsumerStatefulWidget {
  const _OrderIssueCard({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_OrderIssueCard> createState() => _OrderIssueCardState();
}

class _OrderIssueCardState extends ConsumerState<_OrderIssueCard> {
  bool _submitting = false;

  Future<void> _openSupportRequest(_OrderSupportRequestType type) async {
    final tableId = widget.order.tableId;
    if (tableId == null || tableId.trim().isEmpty) return;

    final note = await _showOrderSupportRequestSheet(
      context,
      order: widget.order,
      type: type,
    );
    if (note == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(bellGatewayProvider)
          .ringBell(
            venueId: widget.order.venueId,
            tableId: tableId,
            message: _supportRequestMessage(
              type: type,
              order: widget.order,
              note: note,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(type.snackBarMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not send request.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTable = widget.order.tableId?.trim().isNotEmpty ?? false;
    final requestTypes = _availableSupportRequestTypes(widget.order);

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.bellRing, color: FzColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need help?',
                      style: AppTypography.cardTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasTable
                          ? 'Send an issue, cancellation, or refund review request to staff.'
                          : 'Ask venue staff directly for this order.',
                      style: AppTypography.secondary.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasTable) ...[
            const SizedBox(height: AppSpacing.lg),
            ...requestTypes.map(
              (type) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _openSupportRequest(type),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(type.icon, size: 16),
                    label: Text(type.label),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _OrderSupportRequestType {
  issue,
  cancel,
  refund;

  String get label {
    return switch (this) {
      _OrderSupportRequestType.issue => 'Report issue',
      _OrderSupportRequestType.cancel => 'Request cancellation',
      _OrderSupportRequestType.refund => 'Request refund review',
    };
  }

  IconData get icon {
    return switch (this) {
      _OrderSupportRequestType.issue => LucideIcons.messageSquareWarning,
      _OrderSupportRequestType.cancel => LucideIcons.circleX,
      _OrderSupportRequestType.refund => LucideIcons.receiptText,
    };
  }

  String get sheetTitle {
    return switch (this) {
      _OrderSupportRequestType.issue => 'Report issue',
      _OrderSupportRequestType.cancel => 'Cancellation request',
      _OrderSupportRequestType.refund => 'Refund review',
    };
  }

  String get hint {
    return switch (this) {
      _OrderSupportRequestType.issue => 'Example: missing item or wrong table',
      _OrderSupportRequestType.cancel => 'Tell staff why you need to cancel',
      _OrderSupportRequestType.refund => 'Tell staff what they should review',
    };
  }

  String get snackBarMessage {
    return switch (this) {
      _OrderSupportRequestType.issue => 'Issue request sent to staff.',
      _OrderSupportRequestType.cancel => 'Cancellation request sent to staff.',
      _OrderSupportRequestType.refund => 'Refund review sent to staff.',
    };
  }

  String get auditLabel {
    return switch (this) {
      _OrderSupportRequestType.issue => 'issue',
      _OrderSupportRequestType.cancel => 'cancel_request',
      _OrderSupportRequestType.refund => 'refund_review',
    };
  }
}

List<_OrderSupportRequestType> _availableSupportRequestTypes(OrderModel order) {
  final types = <_OrderSupportRequestType>[_OrderSupportRequestType.issue];
  if (!order.status.isTerminal && !order.status.isServedOrLater) {
    types.add(_OrderSupportRequestType.cancel);
  }
  if (order.paymentStatus == PaymentStatus.paid ||
      order.paymentStatus == PaymentStatus.paymentSubmitted ||
      order.paymentStatus == PaymentStatus.failed ||
      order.paymentStatus == PaymentStatus.disputed ||
      order.status == OrderStatus.served ||
      order.status == OrderStatus.completed) {
    types.add(_OrderSupportRequestType.refund);
  }
  return types;
}

Future<String?> _showOrderSupportRequestSheet(
  BuildContext context, {
  required OrderModel order,
  required _OrderSupportRequestType type,
}) {
  final noteController = TextEditingController();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
      final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: FzColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(type.icon, color: FzColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.sheetTitle,
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Order #${order.orderCode}',
                        style: TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('order_support_note'),
              controller: noteController,
              maxLines: 4,
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.notebookPen),
                labelText: 'Details optional',
                hintText: type.hint,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Staff reviews this request. It does not change order or payment status automatically.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('order_support_submit'),
              onPressed: () {
                Navigator.of(
                  sheetContext,
                ).pop(_normalizeOrderSupportNote(noteController.text) ?? '');
              },
              icon: const Icon(LucideIcons.send, size: 17),
              label: const Text('Send request'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(() {
    _disposeControllersAfterRouteRemoval([noteController]);
  });
}

void _disposeControllersAfterRouteRemoval(
  List<TextEditingController> controllers,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final controller in controllers) {
      controller.dispose();
    }
  });
}

String _supportRequestMessage({
  required _OrderSupportRequestType type,
  required OrderModel order,
  required String note,
}) {
  final details = note.trim().isEmpty ? 'No extra details.' : note.trim();
  return 'Order support ${type.auditLabel}: Order #${order.orderCode}. $details';
}

String? _normalizeOrderSupportNote(String? raw) {
  final normalized = raw?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.length > 180 ? normalized.substring(0, 180) : normalized;
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
