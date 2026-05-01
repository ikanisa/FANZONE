import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/order_model.dart';

/// Gateway for order CRUD and realtime subscriptions.
abstract interface class OrderGateway {
  /// Place a new order. Returns the created order.
  Future<OrderModel> placeOrder(CreateOrderDto request);

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

  /// Get total FET tokens redeemed at a venue.
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

  double get totalAmount => subtotalAmount + tipAmount - paymentFetConvertedAmount;
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

class SupabaseOrderGateway implements OrderGateway {
  SupabaseOrderGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<OrderModel> placeOrder(CreateOrderDto request) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot place order: no connection');
    }

    // Insert order
    final orderRow = await client
        .from('orders')
        .insert({
          'venue_id': request.venueId,
          'table_id': request.tableId,
          'payment_method': request.paymentMethod.name,
          'currency_code': request.currencyCode,
          'subtotal_amount': request.subtotalAmount,
          'tax_amount': 0,
          'tip_amount': request.tipAmount,
          'payment_fet_amount': request.paymentFetAmount,
          'payment_fet_converted_amount': request.paymentFetConvertedAmount,
          'total_amount': request.totalAmount,
          'special_instructions': request.specialInstructions,
        })
        .select()
        .single();

    final orderId = orderRow['id'] as String;

    // Insert order items
    final itemRows = request.items.map((item) => {
      'order_id': orderId,
      'menu_item_id': item.menuItemId,
      'item_name_snapshot': item.itemNameSnapshot,
      'item_description_snapshot': item.itemDescriptionSnapshot,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'line_total': item.lineTotal,
      'currency_code': item.currencyCode,
      'add_ons': item.addOns,
      'special_instructions': item.specialInstructions,
    }).toList();

    await client.from('order_items').insert(itemRows);

    // Fetch complete order with items
    return (await getOrder(orderId))!;
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
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus,
  ) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot update order: no connection');
    }

    await client
        .from('orders')
        .update({'status': newStatus.name})
        .eq('id', orderId);
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

    await client
        .from('orders')
        .update({'payment_status': newStatus.name})
        .eq('id', orderId);
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
    final itemsRaw = row['order_items'];
    List<OrderItemModel>? items;
    if (itemsRaw is List) {
      items = itemsRaw
          .whereType<Map>()
          .map(
            (item) =>
                OrderItemModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    // Remove nested items from the order row before parsing
    final orderData = Map<String, dynamic>.from(row)..remove('order_items');
    final order = OrderModel.fromJson(orderData);
    return order.copyWith(items: items);
  }
}
