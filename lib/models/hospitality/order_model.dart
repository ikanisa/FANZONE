import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

/// Order lifecycle statuses. Maps to `public.order_status` enum.
/// Placed → Received → Served, or Cancelled.
enum OrderStatus {
  @JsonValue('placed')
  placed,
  @JsonValue('received')
  received,
  @JsonValue('served')
  served,
  @JsonValue('cancelled')
  cancelled;

  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Placed';
      case OrderStatus.received:
        return 'Received';
      case OrderStatus.served:
        return 'Served';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Whether this status represents a terminal state.
  bool get isTerminal => this == served || this == cancelled;

  /// Whether this status represents an active (in-progress) state.
  bool get isActive => this == placed || this == received;
}

/// Payment method. Maps to `public.payment_method` enum.
enum PaymentMethod {
  @JsonValue('momo')
  momo,
  @JsonValue('revolut')
  revolut,
  @JsonValue('cash')
  cash;

  String get label {
    switch (this) {
      case PaymentMethod.momo:
        return 'MoMo';
      case PaymentMethod.revolut:
        return 'Revolut';
      case PaymentMethod.cash:
        return 'Cash';
    }
  }
}

/// Payment status. Maps to `public.dinein_payment_status` enum.
enum PaymentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('paid')
  paid,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('refunded')
  refunded;

  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.cancelled:
        return 'Cancelled';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  bool get isPaid => this == PaymentStatus.paid;
}

/// Maps to `public.orders` table.
@freezed
class OrderModel with _$OrderModel {
  const factory OrderModel({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    @JsonKey(name: 'table_id') required String tableId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'order_code') required String orderCode,
    @Default(OrderStatus.placed) OrderStatus status,
    @JsonKey(name: 'payment_method') required PaymentMethod paymentMethod,
    @JsonKey(name: 'payment_status')
    @Default(PaymentStatus.pending)
    PaymentStatus paymentStatus,
    @JsonKey(name: 'payment_reference') String? paymentReference,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @JsonKey(name: 'subtotal_amount') @Default(0) double subtotalAmount,
    @JsonKey(name: 'tax_amount') @Default(0) double taxAmount,
    @JsonKey(name: 'tip_amount') @Default(0) double tipAmount,
    @JsonKey(name: 'payment_fet_amount') @Default(0) int paymentFetAmount,
    @JsonKey(name: 'payment_fet_converted_amount') @Default(0) double paymentFetConvertedAmount,
    @JsonKey(name: 'total_amount') required double totalAmount,
    @JsonKey(name: 'special_instructions') String? specialInstructions,
    @JsonKey(name: 'estimated_ready_at') DateTime? estimatedReadyAt,
    @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
    @JsonKey(name: 'served_at') DateTime? servedAt,
    @JsonKey(name: 'status_changed_at') DateTime? statusChangedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    // Joined data (from expanded queries)
    @JsonKey(includeToJson: false) List<OrderItemModel>? items,
  }) = _OrderModel;

  const OrderModel._();

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  /// Formatted total for display.
  String get totalDisplay {
    if (currencyCode == 'EUR') {
      return '€${totalAmount.toStringAsFixed(2)}';
    } else if (currencyCode == 'RWF') {
      return 'RWF ${totalAmount.toStringAsFixed(0)}';
    }
    return '$currencyCode ${totalAmount.toStringAsFixed(2)}';
  }

  /// Number of items in the order.
  int get itemCount =>
      items?.fold<int>(0, (sum, item) => sum + item.quantity) ?? 0;

  /// Whether the order has been paid.
  bool get isPaid => paymentStatus.isPaid;

  /// FET earned from this order (100 FET per 1 EUR).
  int get estimatedFetEarned {
    const fetPerEur = 100;
    if (currencyCode == 'EUR') {
      return (totalAmount * fetPerEur).floor();
    } else if (currencyCode == 'RWF') {
      return ((totalAmount / 1500) * fetPerEur).floor();
    }
    return 0;
  }
}

/// Maps to `public.order_items` table.
@freezed
class OrderItemModel with _$OrderItemModel {
  const factory OrderItemModel({
    required String id,
    @JsonKey(name: 'order_id') required String orderId,
    @JsonKey(name: 'menu_item_id') String? menuItemId,
    @JsonKey(name: 'item_name_snapshot') required String itemNameSnapshot,
    @JsonKey(name: 'item_description_snapshot') String? itemDescriptionSnapshot,
    required int quantity,
    @JsonKey(name: 'unit_price') required double unitPrice,
    @JsonKey(name: 'line_total') required double lineTotal,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @JsonKey(name: 'add_ons')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> addOns,
    @JsonKey(name: 'special_instructions') String? specialInstructions,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _OrderItemModel;

  const OrderItemModel._();

  factory OrderItemModel.fromJson(Map<String, dynamic> json) =>
      _$OrderItemModelFromJson(json);

  /// Formatted line total for display.
  String get lineTotalDisplay {
    if (currencyCode == 'EUR') {
      return '€${lineTotal.toStringAsFixed(2)}';
    } else if (currencyCode == 'RWF') {
      return 'RWF ${lineTotal.toStringAsFixed(0)}';
    }
    return '$currencyCode ${lineTotal.toStringAsFixed(2)}';
  }
}
