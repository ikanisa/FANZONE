// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderModelImpl _$$OrderModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderModelImpl(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      tableId: json['table_id'] as String?,
      userId: json['user_id'] as String,
      orderCode: json['order_code'] as String,
      status:
          $enumDecodeNullable(_$OrderStatusEnumMap, json['status']) ??
          OrderStatus.submitted,
      paymentMethod: $enumDecode(
        _$PaymentMethodEnumMap,
        json['payment_method'],
      ),
      paymentStatus:
          $enumDecodeNullable(_$PaymentStatusEnumMap, json['payment_status']) ??
          PaymentStatus.pending,
      paymentReference: json['payment_reference'] as String?,
      currencyCode: json['currency_code'] as String,
      subtotalAmount: (json['subtotal_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      tipAmount: (json['tip_amount'] as num?)?.toDouble() ?? 0,
      paymentFetAmount: (json['payment_fet_amount'] as num?)?.toInt() ?? 0,
      fetEarned: (json['fet_earned'] as num?)?.toInt() ?? 0,
      paymentFetConvertedAmount:
          (json['payment_fet_converted_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num).toDouble(),
      specialInstructions: json['special_instructions'] as String?,
      estimatedReadyAt: json['estimated_ready_at'] == null
          ? null
          : DateTime.parse(json['estimated_ready_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      servedAt: json['served_at'] == null
          ? null
          : DateTime.parse(json['served_at'] as String),
      statusChangedAt: json['status_changed_at'] == null
          ? null
          : DateTime.parse(json['status_changed_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$OrderModelImplToJson(_$OrderModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'venue_id': instance.venueId,
      'table_id': instance.tableId,
      'user_id': instance.userId,
      'order_code': instance.orderCode,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'payment_method': _$PaymentMethodEnumMap[instance.paymentMethod]!,
      'payment_status': _$PaymentStatusEnumMap[instance.paymentStatus]!,
      'payment_reference': instance.paymentReference,
      'currency_code': instance.currencyCode,
      'subtotal_amount': instance.subtotalAmount,
      'tax_amount': instance.taxAmount,
      'tip_amount': instance.tipAmount,
      'payment_fet_amount': instance.paymentFetAmount,
      'fet_earned': instance.fetEarned,
      'payment_fet_converted_amount': instance.paymentFetConvertedAmount,
      'total_amount': instance.totalAmount,
      'special_instructions': instance.specialInstructions,
      'estimated_ready_at': instance.estimatedReadyAt?.toIso8601String(),
      'accepted_at': instance.acceptedAt?.toIso8601String(),
      'served_at': instance.servedAt?.toIso8601String(),
      'status_changed_at': instance.statusChangedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$OrderStatusEnumMap = {
  OrderStatus.draft: 'draft',
  OrderStatus.placed: 'placed',
  OrderStatus.received: 'received',
  OrderStatus.submitted: 'submitted',
  OrderStatus.accepted: 'accepted',
  OrderStatus.preparing: 'preparing',
  OrderStatus.ready: 'ready',
  OrderStatus.served: 'served',
  OrderStatus.completed: 'completed',
  OrderStatus.cancelled: 'cancelled',
  OrderStatus.refunded: 'refunded',
  OrderStatus.disputed: 'disputed',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.momo: 'momo',
  PaymentMethod.revolut: 'revolut',
  PaymentMethod.cash: 'cash',
  PaymentMethod.card: 'card',
  PaymentMethod.other: 'other',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'pending',
  PaymentStatus.unpaid: 'unpaid',
  PaymentStatus.paymentSubmitted: 'payment_submitted',
  PaymentStatus.paid: 'paid',
  PaymentStatus.partiallyPaid: 'partially_paid',
  PaymentStatus.failed: 'failed',
  PaymentStatus.cancelled: 'cancelled',
  PaymentStatus.refunded: 'refunded',
  PaymentStatus.disputed: 'disputed',
};

_$OrderItemModelImpl _$$OrderItemModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderItemModelImpl(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      menuItemId: json['menu_item_id'] as String?,
      itemNameSnapshot: json['item_name_snapshot'] as String,
      itemDescriptionSnapshot: json['item_description_snapshot'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      addOns:
          (json['add_ons'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const <Map<String, dynamic>>[],
      specialInstructions: json['special_instructions'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$OrderItemModelImplToJson(
  _$OrderItemModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'order_id': instance.orderId,
  'menu_item_id': instance.menuItemId,
  'item_name_snapshot': instance.itemNameSnapshot,
  'item_description_snapshot': instance.itemDescriptionSnapshot,
  'quantity': instance.quantity,
  'unit_price': instance.unitPrice,
  'line_total': instance.lineTotal,
  'currency_code': instance.currencyCode,
  'add_ons': instance.addOns,
  'special_instructions': instance.specialInstructions,
  'created_at': instance.createdAt?.toIso8601String(),
};
