import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_badge.dart';
import '../providers/venue_dashboard_provider.dart';
import '../../../models/hospitality/order_model.dart';

class VenueDashboardScreen extends ConsumerStatefulWidget {
  const VenueDashboardScreen({super.key});

  @override
  ConsumerState<VenueDashboardScreen> createState() =>
      _VenueDashboardScreenState();
}

class _VenueDashboardScreenState extends ConsumerState<VenueDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(venueDashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Venue Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/venue-dashboard/stakes'),
            icon: const Icon(LucideIcons.trophy),
            tooltip: 'Match Stakes',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            summaryAsync.when(
              data: (s) => Tab(text: 'Orders (${s.activeOrderCount})'),
              loading: () => const Tab(text: 'Orders (...)'),
              error: (_, _) => const Tab(text: 'Orders'),
            ),
            summaryAsync.when(
              data: (s) => Tab(text: 'Bells (${s.pendingBellCount})'),
              loading: () => const Tab(text: 'Bells (...)'),
              error: (_, _) => const Tab(text: 'Bells'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OrderQueueView(),
          _BellQueueView(),
        ],
      ),
    );
  }
}

class _OrderQueueView extends ConsumerWidget {
  const _OrderQueueView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(venueOrdersProvider);

    if (orders.isEmpty) {
      return StateView.empty(
        title: 'No active orders',
        subtitle: 'New orders will appear here in real-time.',
        icon: LucideIcons.clipboardList,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OrderKdsCard(order: order),
        );
      },
    );
  }
}

class _OrderKdsCard extends ConsumerWidget {
  const _OrderKdsCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ORDER #${order.orderCode}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const Spacer(),
              FzBadge(
                label: order.status.label.toUpperCase(),
                variant: order.status == OrderStatus.placed
                    ? FzBadgeVariant.success
                    : FzBadgeVariant.ghost,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...order.items
                  ?.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${item.quantity}x ${item.itemNameSnapshot}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ))
                  .toList() ??
              [],
          if (order.specialInstructions?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FzColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 14, color: FzColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.specialInstructions!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: FzColors.warning,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref
                      .read(venueOrdersProvider.notifier)
                      .updateStatus(
                        order.id,
                        order.status == OrderStatus.placed
                            ? OrderStatus.received
                            : OrderStatus.served,
                      ),
                  child: Text(order.status == OrderStatus.placed
                      ? 'MARK PREPARING'
                      : 'MARK SERVED'),
                ),
              ),
              if (order.status == OrderStatus.placed) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => ref
                      .read(venueOrdersProvider.notifier)
                      .updateStatus(order.id, OrderStatus.cancelled),
                  icon: const Icon(LucideIcons.trash2, color: FzColors.danger),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BellQueueView extends ConsumerWidget {
  const _BellQueueView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bells = ref.watch(venueBellsProvider);

    if (bells.isEmpty) {
      return StateView.empty(
        title: 'All quiet',
        subtitle: 'Table requests will appear here.',
        icon: LucideIcons.bell,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bells.length,
      itemBuilder: (context, index) {
        final bell = bells[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FzCard(
            color: FzColors.accent2.withValues(alpha: 0.05),
            borderColor: FzColors.accent2,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.bellRing, color: FzColors.accent2),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TABLE REQUEST',
                        style: FzTypography.metaLabel(color: FzColors.accent2),
                      ),
                      const Text(
                        'Customer needs assistance',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(venueBellsProvider.notifier).acknowledge(bell.id),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FzColors.accent2,
                      foregroundColor: FzColors.darkBg),
                  child: const Text('ACKNOWLEDGE'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
