/// Riverpod provider for order lifecycle management.
///
/// Handles order placement (cart → Supabase), order tracking
/// with realtime updates, and order history.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../services/app_telemetry.dart';
import '../../../models/hospitality/order_model.dart';
import '../data/order_gateway.dart';
import 'cart_provider.dart';
import 'venue_context_provider.dart';

// ═══════════════════════════════════════════════════════════
// ORDER PLACEMENT STATE
// ═══════════════════════════════════════════════════════════

/// State for the order placement flow.
enum OrderPlacementStatus { idle, placing, success, error }

class OrderPlacementState {
  const OrderPlacementState({
    this.status = OrderPlacementStatus.idle,
    this.order,
    this.errorMessage,
  });

  final OrderPlacementStatus status;
  final OrderModel? order;
  final String? errorMessage;

  bool get isPlacing => status == OrderPlacementStatus.placing;
  bool get isSuccess => status == OrderPlacementStatus.success;
  bool get isError => status == OrderPlacementStatus.error;

  static const idle = OrderPlacementState();
}

/// Manages the order placement lifecycle.
class OrderPlacementNotifier extends StateNotifier<OrderPlacementState> {
  OrderPlacementNotifier(this._orderGateway, this._cartNotifier)
      : super(OrderPlacementState.idle);

  final OrderGateway _orderGateway;
  final CartNotifier _cartNotifier;

  /// Place the current cart as an order.
  Future<OrderModel?> placeOrder({
    required String venueId,
    required String tableId,
    required PaymentMethod paymentMethod,
    required String currencyCode,
  }) async {
    final cart = _cartNotifier.state;
    if (cart.isEmpty) {
      state = const OrderPlacementState(
        status: OrderPlacementStatus.error,
        errorMessage: 'Cart is empty',
      );
      return null;
    }

    state = const OrderPlacementState(status: OrderPlacementStatus.placing);

    try {
      final dto = CreateOrderDto(
        venueId: venueId,
        tableId: tableId,
        paymentMethod: paymentMethod,
        currencyCode: currencyCode,
        items: cart.items.map((item) => item.toOrderItemDto()).toList(),
        specialInstructions: cart.specialInstructions,
        tipAmount: cart.tipAmount,
        paymentFetAmount: cart.appliedFet,
        paymentFetConvertedAmount: cart.discountFromFet,
      );

      final order = await _orderGateway.placeOrder(dto);

      // Track telemetry
      unawaited(AppTelemetry.trackEvent('order_placed', metadata: {
        'order_id': order.id,
        'venue_id': order.venueId,
        'total_amount': order.totalAmount,
        'currency': order.currencyCode,
        'tokens_used': order.paymentFetAmount,
      }));

      // Clear the cart after successful order placement
      _cartNotifier.clear();

      state = OrderPlacementState(
        status: OrderPlacementStatus.success,
        order: order,
      );

      return order;
    } catch (error) {
      state = OrderPlacementState(
        status: OrderPlacementStatus.error,
        errorMessage: 'Failed to place order: $error',
      );
      return null;
    }
  }

  /// Reset placement state (e.g., after navigating away from error).
  void reset() {
    state = OrderPlacementState.idle;
  }
}

final orderPlacementProvider =
    StateNotifierProvider<OrderPlacementNotifier, OrderPlacementState>((ref) {
  return OrderPlacementNotifier(
    ref.watch(orderGatewayProvider),
    ref.watch(cartProvider.notifier),
  );
});

// ═══════════════════════════════════════════════════════════
// ORDER TRACKING
// ═══════════════════════════════════════════════════════════

/// Fetch a single order by ID (with items).
final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderModel?, String>((ref, orderId) {
  final gateway = ref.watch(orderGatewayProvider);
  return gateway.getOrder(orderId);
});

// ═══════════════════════════════════════════════════════════
// ORDER HISTORY
// ═══════════════════════════════════════════════════════════

/// Fetch the current user's order history.
final orderHistoryProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final client =
      ref.watch(supabaseConnectionProvider).client;
  if (client == null) return const [];

  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  final gateway = ref.watch(orderGatewayProvider);
  return gateway.getUserOrders(userId);
});

// ═══════════════════════════════════════════════════════════
// ACTIVE ORDERS (non-terminal)
// ═══════════════════════════════════════════════════════════

/// Active orders for the current user (placed or received, not yet served).
final activeOrdersProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final orders = await ref.watch(orderHistoryProvider.future);
  return orders.where((o) => o.status.isActive).toList();
});

/// Convenience: place order using the current venue context.
Future<OrderModel?> placeOrderFromContext(
  WidgetRef ref, {
  required PaymentMethod paymentMethod,
}) {
  final context = ref.read(venueContextProvider);
  if (!context.hasVenue || !context.hasTable) return Future.value(null);

  return ref.read(orderPlacementProvider.notifier).placeOrder(
        venueId: context.venueId!,
        tableId: context.tableId!,
        paymentMethod: paymentMethod,
        currencyCode: context.currencyCode,
      );
}
