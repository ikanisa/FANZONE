/// Riverpod providers for the venue dashboard (venue owner/staff view).
///
/// Provides live order queue, bell queue, and venue management state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../models/hospitality/bell_request_model.dart';
import '../../../models/hospitality/order_model.dart';
import '../../../models/hospitality/venue_model.dart';
import '../../ordering/data/bell_gateway.dart';
import '../../ordering/data/order_gateway.dart';
import '../../ordering/providers/venue_context_provider.dart';

// ═══════════════════════════════════════════════════════════
// MY VENUES (for venue owner dashboard entry)
// ═══════════════════════════════════════════════════════════

/// Venues managed by the current user.
final myVenuesProvider =
    FutureProvider.autoDispose<List<VenueModel>>((ref) async {
  final client = ref.watch(supabaseConnectionProvider).client;
  if (client == null) return const [];

  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  final gateway = ref.watch(venueGatewayProvider);
  return gateway.getMyVenues(userId);
});

/// Whether the current user manages any venues.
final isVenueOwnerProvider = Provider.autoDispose<bool>((ref) {
  final venues = ref.watch(myVenuesProvider);
  return venues.when(
    data: (v) => v.isNotEmpty,
    loading: () => false,
    error: (_, _) => false,
  );
});

// ═══════════════════════════════════════════════════════════
// VENUE ORDERS (live queue)
// ═══════════════════════════════════════════════════════════

/// Live order queue for the venue dashboard.
class VenueOrdersNotifier extends StateNotifier<List<OrderModel>> {
  VenueOrdersNotifier(this._orderGateway) : super(const []);

  final OrderGateway _orderGateway;
  RealtimeChannel? _subscription;

  /// Load initial orders and subscribe to realtime updates.
  Future<void> loadAndSubscribe(String venueId) async {
    // Load existing orders (active ones)
    final orders = await _orderGateway.getVenueOrders(
      venueId,
      statusFilter: [OrderStatus.placed, OrderStatus.received],
      limit: 100,
    );
    state = orders;

    // Subscribe to realtime updates
    unawaited(_subscription?.unsubscribe());
    _subscription = _orderGateway.subscribeToVenueOrders(
      venueId,
      _handleOrderUpdate,
    );
  }

  void _handleOrderUpdate(OrderModel updatedOrder) {
    final updated = List<OrderModel>.from(state);
    final index = updated.indexWhere((o) => o.id == updatedOrder.id);

    if (index >= 0) {
      // Update existing order
      if (updatedOrder.status.isTerminal) {
        updated.removeAt(index);
      } else {
        updated[index] = updatedOrder;
      }
    } else if (updatedOrder.status.isActive) {
      // New active order — add to front
      updated.insert(0, updatedOrder);
    }

    state = updated;
  }

  /// Update an order's status from the dashboard.
  Future<void> updateStatus(String orderId, OrderStatus newStatus) async {
    await _orderGateway.updateOrderStatus(orderId, newStatus);
  }

  /// Mark an order as paid from the dashboard.
  Future<void> markPaid(String orderId) async {
    await _orderGateway.updatePaymentStatus(orderId, PaymentStatus.paid);
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final venueOrdersProvider =
    StateNotifierProvider.autoDispose<VenueOrdersNotifier, List<OrderModel>>((
  ref,
) {
  final notifier = VenueOrdersNotifier(ref.watch(orderGatewayProvider));

  final context = ref.watch(venueContextProvider);
  if (context.hasVenue) {
    notifier.loadAndSubscribe(context.venueId!);
  }

  return notifier;
});

// ═══════════════════════════════════════════════════════════
// BELL REQUESTS (live queue)
// ═══════════════════════════════════════════════════════════

/// Live bell request queue for the venue dashboard.
class VenueBellsNotifier extends StateNotifier<List<BellRequestModel>> {
  VenueBellsNotifier(this._bellGateway) : super(const []);

  final BellGateway _bellGateway;
  RealtimeChannel? _subscription;

  /// Load active bells and subscribe to realtime new bells.
  Future<void> loadAndSubscribe(String venueId) async {
    final bells = await _bellGateway.getActiveBells(venueId);
    state = bells;

    unawaited(_subscription?.unsubscribe());
    _subscription = _bellGateway.subscribeToVenueBells(
      venueId,
      _handleNewBell,
    );
  }

  void _handleNewBell(BellRequestModel bell) {
    if (!bell.isAcknowledged) {
      state = [bell, ...state];
    }
  }

  /// Acknowledge a bell request.
  Future<void> acknowledge(String bellId) async {
    await _bellGateway.acknowledgeBell(bellId);
    state = state.where((b) => b.id != bellId).toList();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final venueBellsProvider =
    StateNotifierProvider.autoDispose<VenueBellsNotifier, List<BellRequestModel>>(
  (ref) {
    final notifier = VenueBellsNotifier(ref.watch(bellGatewayProvider));

    final context = ref.watch(venueContextProvider);
    if (context.hasVenue) {
      notifier.loadAndSubscribe(context.venueId!);
    }

    return notifier;
  },
);

/// Count of active (unacknowledged) bell requests — for badge display.
final activeBellCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(venueBellsProvider).length;
});

// ═══════════════════════════════════════════════════════════
// DASHBOARD SUMMARY
// ═══════════════════════════════════════════════════════════

/// Quick summary counts for the venue dashboard header.
class VenueDashboardSummary {
  const VenueDashboardSummary({
    this.activeOrderCount = 0,
    this.pendingBellCount = 0,
    this.placedCount = 0,
    this.receivedCount = 0,
    this.redeemedTokenCount = 0,
  });

  final int activeOrderCount;
  final int pendingBellCount;
  final int placedCount;
  final int receivedCount;
  final int redeemedTokenCount;
}

final venueDashboardSummaryProvider =
    FutureProvider.autoDispose<VenueDashboardSummary>((ref) async {
  final orders = ref.watch(venueOrdersProvider);
  final bells = ref.watch(venueBellsProvider);
  final context = ref.watch(venueContextProvider);
  
  int redeemedTokens = 0;
  if (context.hasVenue) {
    redeemedTokens = await ref.read(orderGatewayProvider).getVenueRedeemedTokens(context.venueId!);
  }

  return VenueDashboardSummary(
    activeOrderCount: orders.length,
    pendingBellCount: bells.length,
    placedCount: orders.where((o) => o.status == OrderStatus.placed).length,
    receivedCount: orders.where((o) => o.status == OrderStatus.received).length,
    redeemedTokenCount: redeemedTokens,
  );
});
