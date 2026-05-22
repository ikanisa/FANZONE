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
import '../../../providers/auth_provider.dart';
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
    required String tableNumber,
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
        tableNumber: tableNumber,
        paymentMethod: paymentMethod,
        currencyCode: currencyCode,
        items: cart.items.map((item) => item.toOrderItemDto()).toList(),
        specialInstructions: cart.specialInstructions,
        tipAmount: cart.tipAmount,
        paymentFetAmount: 0,
        paymentFetConvertedAmount: 0,
      );

      final order = await _orderGateway.placeOrder(dto);

      // Track telemetry
      unawaited(
        AppTelemetry.trackEvent(
          'order_placed',
          metadata: {
            'order_id': order.id,
            'venue_id': order.venueId,
            'total_amount': order.totalAmount,
            'currency': order.currencyCode,
            'tokens_used': order.paymentFetAmount,
          },
        ),
      );

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
final orderDetailProvider = FutureProvider.autoDispose
    .family<OrderModel?, String>((ref, orderId) {
      final gateway = ref.watch(orderGatewayProvider);
      return gateway.getOrder(orderId);
    });

/// Track a single order with realtime updates and reload full item detail
/// when the order row changes.
final orderRealtimeProvider = StreamProvider.autoDispose
    .family<OrderModel?, String>((ref, orderId) {
      final gateway = ref.watch(orderGatewayProvider);
      final connection = ref.watch(supabaseConnectionProvider);
      final controller = StreamController<OrderModel?>();

      Future<void> emitLatest() async {
        if (controller.isClosed) return;
        controller.add(await gateway.getOrder(orderId));
      }

      unawaited(emitLatest());

      final client = connection.client;
      final channel = client == null
          ? null
          : gateway.subscribeToOrder(orderId, (_) {
              unawaited(emitLatest());
            });

      ref.onDispose(() {
        if (channel != null && client != null) {
          unawaited(
            Future<void>(() async {
              await client.removeChannel(channel);
            }),
          );
        }
        unawaited(controller.close());
      });

      return controller.stream;
    });

// ═══════════════════════════════════════════════════════════
// ORDER HISTORY
// ═══════════════════════════════════════════════════════════

/// Fetch the current user's order history.
final orderHistoryProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];

  final gateway = ref.watch(orderGatewayProvider);
  return gateway.getUserOrders(userId);
});

// ═══════════════════════════════════════════════════════════
// ACTIVE ORDERS (non-terminal)
// ═══════════════════════════════════════════════════════════

/// Active orders for the current user (placed or received, not yet served).
final activeOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  final orders = await ref.watch(orderHistoryProvider.future);
  return orders.where((o) => o.status.isActive).toList();
});

bool canSubmitPaymentForOrder(OrderModel order) {
  final hasExternalPayment = switch (order.paymentMethod) {
    PaymentMethod.momo || PaymentMethod.revolut || PaymentMethod.other => true,
    PaymentMethod.cash || PaymentMethod.card => false,
  };

  return hasExternalPayment &&
      !order.status.isTerminal &&
      (order.paymentStatus == PaymentStatus.pending ||
          order.paymentStatus == PaymentStatus.unpaid);
}

Future<void> submitPaymentForOrder(WidgetRef ref, OrderModel order) async {
  await ref
      .read(orderGatewayProvider)
      .submitPayment(orderId: order.id, method: order.paymentMethod);

  ref.invalidate(orderDetailProvider(order.id));
  ref.invalidate(orderRealtimeProvider(order.id));
  ref.invalidate(orderHistoryProvider);
  ref.invalidate(activeOrdersProvider);
}

/// Convenience: place order using the current venue context.
Future<OrderModel?> placeOrderFromContext(
  WidgetRef ref, {
  required PaymentMethod paymentMethod,
  required String tableNumber,
}) {
  final context = ref.read(venueContextProvider);
  if (!context.hasVenue) {
    return Future.value(null);
  }

  return ref
      .read(orderPlacementProvider.notifier)
      .placeOrder(
        venueId: context.venueId!,
        tableNumber: tableNumber,
        paymentMethod: paymentMethod,
        currencyCode: context.currencyCode,
      );
}
