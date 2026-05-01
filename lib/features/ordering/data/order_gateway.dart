import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/order_model.dart';

/// Gateway for order CRUD and realtime subscriptions.
abstract interface class OrderGateway {
  /// Place a new order. Returns the created order.
  Future<OrderModel> placeOrder(CreateOrderDto request);

  /// Create an external payment handoff. This never marks the order paid.
  Future<PaymentHandoff> createPaymentHandoff({
    required String orderId,
    required String venueId,
    required PaymentMethod method,
  });

  /// Get a single order by ID (with items).
  Future<OrderModel?> getOrder(String orderId);

  /// List orders for the current user.
  Future<List<OrderModel>> getUserOrders(String userId, {int limit});

  /// List orders for a venue (venue dashboard).
  Future<List<OrderModel>> getVenueOrders(
    String venueId, {
    List<OrderStatus>? statusFilter,
    int limit,
  });

  /// Update order status (venue dashboard action).
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus);

  /// Update payment status (venue dashboard action).
  Future<void> updatePaymentStatus(String orderId, PaymentStatus newStatus);

  /// Spend FET against an order through the wallet ledger RPC.
  Future<void> spendFetOnOrder({
    required String orderId,
    required int amountFet,
  });

  /// Subscribe to realtime order updates for a specific order.
  RealtimeChannel subscribeToOrder(
    String orderId,
    void Function(OrderModel order) onUpdate,
  );

  /// Subscribe to realtime new/updated orders for a venue.
  RealtimeChannel subscribeToVenueOrders(
    String venueId,
    void Function(OrderModel order) onUpdate,
  );

  /// Get total FET redeemed at a venue.
  Future<int> getVenueRedeemedTokens(String venueId);
}

/// DTO for creating a new order.
class CreateOrderDto {
  const CreateOrderDto({
    required this.venueId,
    required this.tableId,
    required this.paymentMethod,
    required this.currencyCode,
    required this.items,
    this.specialInstructions,
    this.tipAmount = 0,
    this.paymentFetAmount = 0,
    this.paymentFetConvertedAmount = 0,
  });

  final String venueId;
  final String tableId;
  final PaymentMethod paymentMethod;
  final String currencyCode;
  final List<CreateOrderItemDto> items;
  final String? specialInstructions;
  final double tipAmount;
  final int paymentFetAmount;
  final double paymentFetConvertedAmount;

  double get subtotalAmount =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get totalAmount => subtotalAmount + tipAmount;
}

/// DTO for a single item in a new order.
class CreateOrderItemDto {
  const CreateOrderItemDto({
    required this.menuItemId,
    required this.itemNameSnapshot,
    this.itemDescriptionSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.currencyCode,
    this.addOns = const [],
    this.specialInstructions,
  });

  final String menuItemId;
  final String itemNameSnapshot;
  final String? itemDescriptionSnapshot;
  final int quantity;
  final double unitPrice;
  final String currencyCode;
  final List<Map<String, dynamic>> addOns;
  final String? specialInstructions;

  double get lineTotal => unitPrice * quantity;
}

/// External payment handoff returned by `payment-hub`.
class PaymentHandoff {
  const PaymentHandoff({
    required this.method,
    required this.amount,
    required this.currency,
    required this.instructions,
    required this.requiresStaffConfirmation,
    this.ussdString,
    this.paymentUrl,
  });

  final PaymentMethod method;
  final String amount;
  final String currency;
  final List<String> instructions;
  final bool requiresStaffConfirmation;
  final String? ussdString;
  final String? paymentUrl;

  factory PaymentHandoff.fromJson(Map<String, dynamic> json) {
    final methodName = json['method']?.toString() ?? 'cash';
    final method = PaymentMethod.values.firstWhere(
      (value) => value.name == methodName,
      orElse: () => PaymentMethod.cash,
    );
    final rawInstructions = json['instructions'];

    return PaymentHandoff(
      method: method,
      amount: json['amount']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      instructions: rawInstructions is List
          ? rawInstructions.map((item) => item.toString()).toList()
          : const [],
      requiresStaffConfirmation:
          json['requires_staff_confirmation'] as bool? ?? true,
      ussdString: json['ussd_string']?.toString(),
      paymentUrl: json['payment_url']?.toString(),
    );
  }
}

class SupabaseOrderGateway implements OrderGateway {
  SupabaseOrderGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<OrderModel> placeOrder(CreateOrderDto request) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot place order: no connection');
    }

    final response = await client.functions.invoke(
      'order_create',
      body: {
        'venue_id': request.venueId,
        'table_id': request.tableId,
        'payment_method': request.paymentMethod.name,
        'special_instructions': request.specialInstructions,
        'items': request.items
            .map(
              (item) => {
                'menu_item_id': item.menuItemId,
                'quantity': item.quantity,
                'add_ons': item.addOns,
              },
            )
            .toList(),
      },
    );

    final data = Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const {},
    );
    if (data['success'] != true || data['order'] is! Map) {
      throw StateError('Order creation failed');
    }

    return _parseOrderWithItems(
      Map<String, dynamic>.from(data['order'] as Map),
    );
  }

  @override
  Future<PaymentHandoff> createPaymentHandoff({
    required String orderId,
    required String venueId,
    required PaymentMethod method,
  }) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot create payment handoff: no connection');
    }

    if (method == PaymentMethod.cash) {
      throw ArgumentError('Cash payments do not need an external handoff');
    }

    final response = await client.functions.invoke(
      'payment-hub',
      body: {'order_id': orderId, 'venue_id': venueId, 'method': method.name},
    );

    final data = Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const {},
    );
    if (data['success'] != true) {
      throw StateError(
        data['error']?.toString() ?? 'Payment handoff unavailable',
      );
    }

    return PaymentHandoff.fromJson(data);
  }

  @override
  Future<void> spendFetOnOrder({
    required String orderId,
    required int amountFet,
  }) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot spend FET: no connection');
    }
    if (amountFet <= 0) return;

    await client.rpc(
      'spend_fet_on_order',
      params: {
        'p_order_id': orderId,
        'p_amount_fet': amountFet,
        'p_idempotency_key': 'order_spend:$orderId:$amountFet',
      },
    );
  }

  @override
  Future<OrderModel?> getOrder(String orderId) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .maybeSingle();

      if (row == null) return null;
      return _parseOrderWithItems(row);
    } catch (error) {
      AppLogger.w('Failed to load order: $error');
      return null;
    }
  }

  @override
  Future<List<OrderModel>> getUserOrders(
    String userId, {
    int limit = 20,
  }) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .whereType<Map>()
          .map((row) => _parseOrderWithItems(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to load user orders: $error');
      return const [];
    }
  }

  @override
  Future<List<OrderModel>> getVenueOrders(
    String venueId, {
    List<OrderStatus>? statusFilter,
    int limit = 50,
  }) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      var query = client
          .from('orders')
          .select('*, order_items(*)')
          .eq('venue_id', venueId);

      if (statusFilter != null && statusFilter.isNotEmpty) {
        final statusValues = statusFilter.map((s) => s.name).toList();
        query = query.inFilter('status', statusValues);
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .whereType<Map>()
          .map((row) => _parseOrderWithItems(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to load venue orders: $error');
      return const [];
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot update order: no connection');
    }

    await client.functions.invoke(
      'order_update_status',
      body: {'order_id': orderId, 'status': newStatus.name},
    );
  }

  @override
  Future<void> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus,
  ) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot update payment: no connection');
    }

    if (newStatus != PaymentStatus.paid) {
      throw UnsupportedError(
        'Only manual paid confirmation is supported from the venue dashboard',
      );
    }

    await client.functions.invoke(
      'order_mark_paid',
      body: {'order_id': orderId},
    );
  }

  @override
  Future<int> getVenueRedeemedTokens(String venueId) async {
    final client = _connection.client;
    if (client == null) return 0;

    try {
      final response = await client
          .from('orders')
          .select('payment_fet_amount')
          .eq('venue_id', venueId)
          .neq('status', 'cancelled');

      final total = (response as List).fold<int>(
        0,
        (sum, row) => sum + (row['payment_fet_amount'] as int? ?? 0),
      );
      return total;
    } catch (e) {
      AppLogger.w('Failed to get redeemed tokens: $e');
      return 0;
    }
  }

  @override
  RealtimeChannel subscribeToOrder(
    String orderId,
    void Function(OrderModel order) onUpdate,
  ) {
    final client = _connection.client!;
    return client
        .channel('order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            try {
              final newData = payload.newRecord;
              if (newData.isNotEmpty) {
                onUpdate(OrderModel.fromJson(newData));
              }
            } catch (e) {
              AppLogger.w('Error parsing realtime order update: $e');
            }
          },
        )
        .subscribe();
  }

  @override
  RealtimeChannel subscribeToVenueOrders(
    String venueId,
    void Function(OrderModel order) onUpdate,
  ) {
    final client = _connection.client!;
    return client
        .channel('venue_orders_$venueId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'venue_id',
            value: venueId,
          ),
          callback: (payload) {
            try {
              final data = payload.newRecord;
              if (data.isNotEmpty) {
                onUpdate(OrderModel.fromJson(data));
              }
            } catch (e) {
              AppLogger.w('Error parsing realtime venue order update: $e');
            }
          },
        )
        .subscribe();
  }

  OrderModel _parseOrderWithItems(Map<String, dynamic> row) {
    final itemsRaw = row['order_items'] ?? row['items'];
    List<OrderItemModel>? items;
    if (itemsRaw is List) {
      items = itemsRaw
          .whereType<Map>()
          .map(
            (item) => OrderItemModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    // Remove nested items from the order row before parsing
    final orderData = Map<String, dynamic>.from(row)
      ..remove('order_items')
      ..remove('items');
    final order = OrderModel.fromJson(orderData);
    return order.copyWith(items: items);
  }
}
