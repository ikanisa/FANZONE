import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
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

  /// Mark that the customer completed the external payment handoff.
  ///
  /// This never marks the order paid; venue staff still confirm payment.
  Future<void> submitPayment({
    required String orderId,
    required PaymentMethod method,
    String? externalReference,
    String? note,
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
  Future<void> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus, {
    required String note,
    PaymentMethod method = PaymentMethod.cash,
    double? amountReceived,
    String? externalReference,
  });

  /// Redeem FET against an order through the rewards ledger RPC.
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
    required this.tableNumber,
    required this.paymentMethod,
    required this.currencyCode,
    required this.items,
    this.specialInstructions,
    this.tipAmount = 0,
    this.paymentFetAmount = 0,
    this.paymentFetConvertedAmount = 0,
  });

  final String venueId;
  final String tableNumber;
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
    final parsedMethod = PaymentMethod.values.firstWhere(
      (value) => value.name == methodName,
      orElse: () => PaymentMethod.cash,
    );
    final method = switch (parsedMethod) {
      PaymentMethod.momo || PaymentMethod.revolut => parsedMethod,
      PaymentMethod.cash ||
      PaymentMethod.card ||
      PaymentMethod.other => PaymentMethod.cash,
    };
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
  final Map<String, OrderModel> _devFixtureOrders = <String, OrderModel>{};

  Map<String, String>? get _authHeaders {
    final token = _connection.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<OrderModel> placeOrder(CreateOrderDto request) async {
    if (_connection.isDevOtpFixtureSession) {
      return _placeDevFixtureOrder(request);
    }

    _assertReviewMutationAllowed('Order creation');
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot place order: no connection');
    }

    final response = await client.functions.invoke(
      'order_create',
      headers: _authHeaders,
      body: {
        'venue_id': request.venueId,
        'table_number': request.tableNumber,
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
    _assertReviewMutationAllowed('Payment handoff creation');
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot create payment handoff: no connection');
    }

    if (method == PaymentMethod.cash || method == PaymentMethod.card) {
      throw ArgumentError(
        'This payment method does not need an external handoff',
      );
    }

    final response = await client.functions.invoke(
      'payment-hub',
      headers: _authHeaders,
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
  Future<void> submitPayment({
    required String orderId,
    required PaymentMethod method,
    String? externalReference,
    String? note,
  }) async {
    _assertReviewMutationAllowed('Payment submission');
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot submit payment: no connection');
    }

    await client.rpc(
      'user_submit_order_payment',
      params: {
        'p_order_id': orderId,
        'p_payment_method': method.name,
        'p_external_reference': externalReference,
        'p_actor_note': note,
      },
    );
  }

  @override
  Future<void> spendFetOnOrder({
    required String orderId,
    required int amountFet,
  }) async {
    _assertReviewMutationAllowed('FET order spending');
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
    if (_connection.isDevOtpFixtureSession) {
      return _devFixtureOrders[orderId];
    }

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
    if (_connection.isDevOtpFixtureSession) {
      final orders = _devFixtureOrders.values.toList(growable: false)
        ..sort((a, b) {
          final aCreated =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bCreated =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bCreated.compareTo(aCreated);
        });
      return orders.take(limit).toList(growable: false);
    }

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
    _assertReviewMutationAllowed('Order status updates');
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot update order: no connection');
    }

    await client.functions.invoke(
      'order_update_status',
      headers: _authHeaders,
      body: {'order_id': orderId, 'status': newStatus.name},
    );
  }

  @override
  Future<void> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus, {
    required String note,
    PaymentMethod method = PaymentMethod.cash,
    double? amountReceived,
    String? externalReference,
  }) async {
    _assertReviewMutationAllowed('Payment status updates');
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
      headers: _authHeaders,
      body: buildOrderMarkPaidBody(
        orderId: orderId,
        method: method,
        note: note,
        amountReceived: amountReceived,
        externalReference: externalReference,
      ),
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

  OrderModel _placeDevFixtureOrder(CreateOrderDto request) {
    final now = DateTime.now().toUtc();
    final timestamp = now.microsecondsSinceEpoch;
    final orderId = 'dev-uat-order-$timestamp';
    final userId =
        _connection.currentUser?.id ?? '00000000-0000-4000-8000-000000000356';
    final orderItems = <OrderItemModel>[
      for (var index = 0; index < request.items.length; index += 1)
        OrderItemModel(
          id: '$orderId-item-${index + 1}',
          orderId: orderId,
          menuItemId: request.items[index].menuItemId,
          itemNameSnapshot: request.items[index].itemNameSnapshot,
          itemDescriptionSnapshot: request.items[index].itemDescriptionSnapshot,
          quantity: request.items[index].quantity,
          unitPrice: request.items[index].unitPrice,
          lineTotal: request.items[index].lineTotal,
          currencyCode: request.items[index].currencyCode,
          addOns: request.items[index].addOns,
          specialInstructions: request.items[index].specialInstructions,
          createdAt: now,
        ),
    ];
    final order = OrderModel(
      id: orderId,
      venueId: request.venueId,
      userId: userId,
      orderCode: 'UAT-${timestamp.toString().substring(8)}',
      status: OrderStatus.submitted,
      paymentMethod: request.paymentMethod,
      paymentStatus: PaymentStatus.unpaid,
      currencyCode: request.currencyCode,
      subtotalAmount: request.subtotalAmount,
      tipAmount: request.tipAmount,
      totalAmount: request.totalAmount,
      specialInstructions: request.specialInstructions,
      createdAt: now,
      updatedAt: now,
      statusChangedAt: now,
      items: orderItems,
    );
    _devFixtureOrders[orderId] = order;
    return order;
  }

  void _assertReviewMutationAllowed(String action) {
    if (!AppConfig.isReviewMode) return;
    throw StateError(
      '$action is disabled in the FANZONE review PWA. Use staging-safe test data for browser review.',
    );
  }
}

Map<String, dynamic> buildOrderMarkPaidBody({
  required String orderId,
  PaymentMethod method = PaymentMethod.cash,
  required String note,
  double? amountReceived,
  String? externalReference,
}) {
  final trimmedNote = note.trim();
  if (trimmedNote.isEmpty) {
    throw ArgumentError.value(
      note,
      'note',
      'Manual paid confirmation requires an actor note',
    );
  }
  if (method == PaymentMethod.card) {
    throw ArgumentError.value(
      method.name,
      'method',
      'Card is not supported for manual payment confirmation',
    );
  }

  final body = <String, dynamic>{
    'order_id': orderId,
    'payment_method': method.name,
    'note': trimmedNote,
  };
  if (amountReceived != null) {
    body['amount_received'] = amountReceived;
  }
  if (externalReference != null && externalReference.trim().isNotEmpty) {
    body['external_reference'] = externalReference.trim();
  }
  return body;
}
