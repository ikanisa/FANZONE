// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) {
  return _OrderModel.fromJson(json);
}

/// @nodoc
mixin _$OrderModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String get venueId => throw _privateConstructorUsedError;
  @JsonKey(name: 'table_id')
  String get tableId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_code')
  String get orderCode => throw _privateConstructorUsedError;
  OrderStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_method')
  PaymentMethod get paymentMethod => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_status')
  PaymentStatus get paymentStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_reference')
  String? get paymentReference => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_code')
  String get currencyCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'subtotal_amount')
  double get subtotalAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'tax_amount')
  double get taxAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'tip_amount')
  double get tipAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_fet_amount')
  int get paymentFetAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'fet_earned')
  int get fetEarned => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_fet_converted_amount')
  double get paymentFetConvertedAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_amount')
  double get totalAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'special_instructions')
  String? get specialInstructions => throw _privateConstructorUsedError;
  @JsonKey(name: 'estimated_ready_at')
  DateTime? get estimatedReadyAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'accepted_at')
  DateTime? get acceptedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'served_at')
  DateTime? get servedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'status_changed_at')
  DateTime? get statusChangedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError; // Joined data (from expanded queries)
  @JsonKey(includeToJson: false)
  List<OrderItemModel>? get items => throw _privateConstructorUsedError;

  /// Serializes this OrderModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderModelCopyWith<OrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderModelCopyWith<$Res> {
  factory $OrderModelCopyWith(
    OrderModel value,
    $Res Function(OrderModel) then,
  ) = _$OrderModelCopyWithImpl<$Res, OrderModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'table_id') String tableId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'order_code') String orderCode,
    OrderStatus status,
    @JsonKey(name: 'payment_method') PaymentMethod paymentMethod,
    @JsonKey(name: 'payment_status') PaymentStatus paymentStatus,
    @JsonKey(name: 'payment_reference') String? paymentReference,
    @JsonKey(name: 'currency_code') String currencyCode,
    @JsonKey(name: 'subtotal_amount') double subtotalAmount,
    @JsonKey(name: 'tax_amount') double taxAmount,
    @JsonKey(name: 'tip_amount') double tipAmount,
    @JsonKey(name: 'payment_fet_amount') int paymentFetAmount,
    @JsonKey(name: 'fet_earned') int fetEarned,
    @JsonKey(name: 'payment_fet_converted_amount')
    double paymentFetConvertedAmount,
    @JsonKey(name: 'total_amount') double totalAmount,
    @JsonKey(name: 'special_instructions') String? specialInstructions,
    @JsonKey(name: 'estimated_ready_at') DateTime? estimatedReadyAt,
    @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
    @JsonKey(name: 'served_at') DateTime? servedAt,
    @JsonKey(name: 'status_changed_at') DateTime? statusChangedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(includeToJson: false) List<OrderItemModel>? items,
  });
}

/// @nodoc
class _$OrderModelCopyWithImpl<$Res, $Val extends OrderModel>
    implements $OrderModelCopyWith<$Res> {
  _$OrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? tableId = null,
    Object? userId = null,
    Object? orderCode = null,
    Object? status = null,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? paymentReference = freezed,
    Object? currencyCode = null,
    Object? subtotalAmount = null,
    Object? taxAmount = null,
    Object? tipAmount = null,
    Object? paymentFetAmount = null,
    Object? fetEarned = null,
    Object? paymentFetConvertedAmount = null,
    Object? totalAmount = null,
    Object? specialInstructions = freezed,
    Object? estimatedReadyAt = freezed,
    Object? acceptedAt = freezed,
    Object? servedAt = freezed,
    Object? statusChangedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? items = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            venueId: null == venueId
                ? _value.venueId
                : venueId // ignore: cast_nullable_to_non_nullable
                      as String,
            tableId: null == tableId
                ? _value.tableId
                : tableId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            orderCode: null == orderCode
                ? _value.orderCode
                : orderCode // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as OrderStatus,
            paymentMethod: null == paymentMethod
                ? _value.paymentMethod
                : paymentMethod // ignore: cast_nullable_to_non_nullable
                      as PaymentMethod,
            paymentStatus: null == paymentStatus
                ? _value.paymentStatus
                : paymentStatus // ignore: cast_nullable_to_non_nullable
                      as PaymentStatus,
            paymentReference: freezed == paymentReference
                ? _value.paymentReference
                : paymentReference // ignore: cast_nullable_to_non_nullable
                      as String?,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            subtotalAmount: null == subtotalAmount
                ? _value.subtotalAmount
                : subtotalAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            taxAmount: null == taxAmount
                ? _value.taxAmount
                : taxAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            tipAmount: null == tipAmount
                ? _value.tipAmount
                : tipAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            paymentFetAmount: null == paymentFetAmount
                ? _value.paymentFetAmount
                : paymentFetAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            fetEarned: null == fetEarned
                ? _value.fetEarned
                : fetEarned // ignore: cast_nullable_to_non_nullable
                      as int,
            paymentFetConvertedAmount: null == paymentFetConvertedAmount
                ? _value.paymentFetConvertedAmount
                : paymentFetConvertedAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            totalAmount: null == totalAmount
                ? _value.totalAmount
                : totalAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            specialInstructions: freezed == specialInstructions
                ? _value.specialInstructions
                : specialInstructions // ignore: cast_nullable_to_non_nullable
                      as String?,
            estimatedReadyAt: freezed == estimatedReadyAt
                ? _value.estimatedReadyAt
                : estimatedReadyAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            acceptedAt: freezed == acceptedAt
                ? _value.acceptedAt
                : acceptedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            servedAt: freezed == servedAt
                ? _value.servedAt
                : servedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            statusChangedAt: freezed == statusChangedAt
                ? _value.statusChangedAt
                : statusChangedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            items: freezed == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<OrderItemModel>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderModelImplCopyWith<$Res>
    implements $OrderModelCopyWith<$Res> {
  factory _$$OrderModelImplCopyWith(
    _$OrderModelImpl value,
    $Res Function(_$OrderModelImpl) then,
  ) = __$$OrderModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'venue_id') String venueId,
    @JsonKey(name: 'table_id') String tableId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'order_code') String orderCode,
    OrderStatus status,
    @JsonKey(name: 'payment_method') PaymentMethod paymentMethod,
    @JsonKey(name: 'payment_status') PaymentStatus paymentStatus,
    @JsonKey(name: 'payment_reference') String? paymentReference,
    @JsonKey(name: 'currency_code') String currencyCode,
    @JsonKey(name: 'subtotal_amount') double subtotalAmount,
    @JsonKey(name: 'tax_amount') double taxAmount,
    @JsonKey(name: 'tip_amount') double tipAmount,
    @JsonKey(name: 'payment_fet_amount') int paymentFetAmount,
    @JsonKey(name: 'fet_earned') int fetEarned,
    @JsonKey(name: 'payment_fet_converted_amount')
    double paymentFetConvertedAmount,
    @JsonKey(name: 'total_amount') double totalAmount,
    @JsonKey(name: 'special_instructions') String? specialInstructions,
    @JsonKey(name: 'estimated_ready_at') DateTime? estimatedReadyAt,
    @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
    @JsonKey(name: 'served_at') DateTime? servedAt,
    @JsonKey(name: 'status_changed_at') DateTime? statusChangedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(includeToJson: false) List<OrderItemModel>? items,
  });
}

/// @nodoc
class __$$OrderModelImplCopyWithImpl<$Res>
    extends _$OrderModelCopyWithImpl<$Res, _$OrderModelImpl>
    implements _$$OrderModelImplCopyWith<$Res> {
  __$$OrderModelImplCopyWithImpl(
    _$OrderModelImpl _value,
    $Res Function(_$OrderModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? tableId = null,
    Object? userId = null,
    Object? orderCode = null,
    Object? status = null,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? paymentReference = freezed,
    Object? currencyCode = null,
    Object? subtotalAmount = null,
    Object? taxAmount = null,
    Object? tipAmount = null,
    Object? paymentFetAmount = null,
    Object? fetEarned = null,
    Object? paymentFetConvertedAmount = null,
    Object? totalAmount = null,
    Object? specialInstructions = freezed,
    Object? estimatedReadyAt = freezed,
    Object? acceptedAt = freezed,
    Object? servedAt = freezed,
    Object? statusChangedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? items = freezed,
  }) {
    return _then(
      _$OrderModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        tableId: null == tableId
            ? _value.tableId
            : tableId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        orderCode: null == orderCode
            ? _value.orderCode
            : orderCode // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as OrderStatus,
        paymentMethod: null == paymentMethod
            ? _value.paymentMethod
            : paymentMethod // ignore: cast_nullable_to_non_nullable
                  as PaymentMethod,
        paymentStatus: null == paymentStatus
            ? _value.paymentStatus
            : paymentStatus // ignore: cast_nullable_to_non_nullable
                  as PaymentStatus,
        paymentReference: freezed == paymentReference
            ? _value.paymentReference
            : paymentReference // ignore: cast_nullable_to_non_nullable
                  as String?,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        subtotalAmount: null == subtotalAmount
            ? _value.subtotalAmount
            : subtotalAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        taxAmount: null == taxAmount
            ? _value.taxAmount
            : taxAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        tipAmount: null == tipAmount
            ? _value.tipAmount
            : tipAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        paymentFetAmount: null == paymentFetAmount
            ? _value.paymentFetAmount
            : paymentFetAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        fetEarned: null == fetEarned
            ? _value.fetEarned
            : fetEarned // ignore: cast_nullable_to_non_nullable
                  as int,
        paymentFetConvertedAmount: null == paymentFetConvertedAmount
            ? _value.paymentFetConvertedAmount
            : paymentFetConvertedAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        totalAmount: null == totalAmount
            ? _value.totalAmount
            : totalAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        specialInstructions: freezed == specialInstructions
            ? _value.specialInstructions
            : specialInstructions // ignore: cast_nullable_to_non_nullable
                  as String?,
        estimatedReadyAt: freezed == estimatedReadyAt
            ? _value.estimatedReadyAt
            : estimatedReadyAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        acceptedAt: freezed == acceptedAt
            ? _value.acceptedAt
            : acceptedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        servedAt: freezed == servedAt
            ? _value.servedAt
            : servedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        statusChangedAt: freezed == statusChangedAt
            ? _value.statusChangedAt
            : statusChangedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        items: freezed == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<OrderItemModel>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderModelImpl extends _OrderModel {
  const _$OrderModelImpl({
    required this.id,
    @JsonKey(name: 'venue_id') required this.venueId,
    @JsonKey(name: 'table_id') required this.tableId,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'order_code') required this.orderCode,
    this.status = OrderStatus.placed,
    @JsonKey(name: 'payment_method') required this.paymentMethod,
    @JsonKey(name: 'payment_status') this.paymentStatus = PaymentStatus.pending,
    @JsonKey(name: 'payment_reference') this.paymentReference,
    @JsonKey(name: 'currency_code') required this.currencyCode,
    @JsonKey(name: 'subtotal_amount') this.subtotalAmount = 0,
    @JsonKey(name: 'tax_amount') this.taxAmount = 0,
    @JsonKey(name: 'tip_amount') this.tipAmount = 0,
    @JsonKey(name: 'payment_fet_amount') this.paymentFetAmount = 0,
    @JsonKey(name: 'fet_earned') this.fetEarned = 0,
    @JsonKey(name: 'payment_fet_converted_amount')
    this.paymentFetConvertedAmount = 0,
    @JsonKey(name: 'total_amount') required this.totalAmount,
    @JsonKey(name: 'special_instructions') this.specialInstructions,
    @JsonKey(name: 'estimated_ready_at') this.estimatedReadyAt,
    @JsonKey(name: 'accepted_at') this.acceptedAt,
    @JsonKey(name: 'served_at') this.servedAt,
    @JsonKey(name: 'status_changed_at') this.statusChangedAt,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
    @JsonKey(includeToJson: false) final List<OrderItemModel>? items,
  }) : _items = items,
       super._();

  factory _$OrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'venue_id')
  final String venueId;
  @override
  @JsonKey(name: 'table_id')
  final String tableId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'order_code')
  final String orderCode;
  @override
  @JsonKey()
  final OrderStatus status;
  @override
  @JsonKey(name: 'payment_method')
  final PaymentMethod paymentMethod;
  @override
  @JsonKey(name: 'payment_status')
  final PaymentStatus paymentStatus;
  @override
  @JsonKey(name: 'payment_reference')
  final String? paymentReference;
  @override
  @JsonKey(name: 'currency_code')
  final String currencyCode;
  @override
  @JsonKey(name: 'subtotal_amount')
  final double subtotalAmount;
  @override
  @JsonKey(name: 'tax_amount')
  final double taxAmount;
  @override
  @JsonKey(name: 'tip_amount')
  final double tipAmount;
  @override
  @JsonKey(name: 'payment_fet_amount')
  final int paymentFetAmount;
  @override
  @JsonKey(name: 'fet_earned')
  final int fetEarned;
  @override
  @JsonKey(name: 'payment_fet_converted_amount')
  final double paymentFetConvertedAmount;
  @override
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @override
  @JsonKey(name: 'special_instructions')
  final String? specialInstructions;
  @override
  @JsonKey(name: 'estimated_ready_at')
  final DateTime? estimatedReadyAt;
  @override
  @JsonKey(name: 'accepted_at')
  final DateTime? acceptedAt;
  @override
  @JsonKey(name: 'served_at')
  final DateTime? servedAt;
  @override
  @JsonKey(name: 'status_changed_at')
  final DateTime? statusChangedAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  // Joined data (from expanded queries)
  final List<OrderItemModel>? _items;
  // Joined data (from expanded queries)
  @override
  @JsonKey(includeToJson: false)
  List<OrderItemModel>? get items {
    final value = _items;
    if (value == null) return null;
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'OrderModel(id: $id, venueId: $venueId, tableId: $tableId, userId: $userId, orderCode: $orderCode, status: $status, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, paymentReference: $paymentReference, currencyCode: $currencyCode, subtotalAmount: $subtotalAmount, taxAmount: $taxAmount, tipAmount: $tipAmount, paymentFetAmount: $paymentFetAmount, fetEarned: $fetEarned, paymentFetConvertedAmount: $paymentFetConvertedAmount, totalAmount: $totalAmount, specialInstructions: $specialInstructions, estimatedReadyAt: $estimatedReadyAt, acceptedAt: $acceptedAt, servedAt: $servedAt, statusChangedAt: $statusChangedAt, createdAt: $createdAt, updatedAt: $updatedAt, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.tableId, tableId) || other.tableId == tableId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.orderCode, orderCode) ||
                other.orderCode == orderCode) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.paymentReference, paymentReference) ||
                other.paymentReference == paymentReference) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.subtotalAmount, subtotalAmount) ||
                other.subtotalAmount == subtotalAmount) &&
            (identical(other.taxAmount, taxAmount) ||
                other.taxAmount == taxAmount) &&
            (identical(other.tipAmount, tipAmount) ||
                other.tipAmount == tipAmount) &&
            (identical(other.paymentFetAmount, paymentFetAmount) ||
                other.paymentFetAmount == paymentFetAmount) &&
            (identical(other.fetEarned, fetEarned) ||
                other.fetEarned == fetEarned) &&
            (identical(
                  other.paymentFetConvertedAmount,
                  paymentFetConvertedAmount,
                ) ||
                other.paymentFetConvertedAmount == paymentFetConvertedAmount) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.specialInstructions, specialInstructions) ||
                other.specialInstructions == specialInstructions) &&
            (identical(other.estimatedReadyAt, estimatedReadyAt) ||
                other.estimatedReadyAt == estimatedReadyAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.servedAt, servedAt) ||
                other.servedAt == servedAt) &&
            (identical(other.statusChangedAt, statusChangedAt) ||
                other.statusChangedAt == statusChangedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    venueId,
    tableId,
    userId,
    orderCode,
    status,
    paymentMethod,
    paymentStatus,
    paymentReference,
    currencyCode,
    subtotalAmount,
    taxAmount,
    tipAmount,
    paymentFetAmount,
    fetEarned,
    paymentFetConvertedAmount,
    totalAmount,
    specialInstructions,
    estimatedReadyAt,
    acceptedAt,
    servedAt,
    statusChangedAt,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_items),
  ]);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      __$$OrderModelImplCopyWithImpl<_$OrderModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderModelImplToJson(this);
  }
}

abstract class _OrderModel extends OrderModel {
  const factory _OrderModel({
    required final String id,
    @JsonKey(name: 'venue_id') required final String venueId,
    @JsonKey(name: 'table_id') required final String tableId,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'order_code') required final String orderCode,
    final OrderStatus status,
    @JsonKey(name: 'payment_method') required final PaymentMethod paymentMethod,
    @JsonKey(name: 'payment_status') final PaymentStatus paymentStatus,
    @JsonKey(name: 'payment_reference') final String? paymentReference,
    @JsonKey(name: 'currency_code') required final String currencyCode,
    @JsonKey(name: 'subtotal_amount') final double subtotalAmount,
    @JsonKey(name: 'tax_amount') final double taxAmount,
    @JsonKey(name: 'tip_amount') final double tipAmount,
    @JsonKey(name: 'payment_fet_amount') final int paymentFetAmount,
    @JsonKey(name: 'fet_earned') final int fetEarned,
    @JsonKey(name: 'payment_fet_converted_amount')
    final double paymentFetConvertedAmount,
    @JsonKey(name: 'total_amount') required final double totalAmount,
    @JsonKey(name: 'special_instructions') final String? specialInstructions,
    @JsonKey(name: 'estimated_ready_at') final DateTime? estimatedReadyAt,
    @JsonKey(name: 'accepted_at') final DateTime? acceptedAt,
    @JsonKey(name: 'served_at') final DateTime? servedAt,
    @JsonKey(name: 'status_changed_at') final DateTime? statusChangedAt,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
    @JsonKey(includeToJson: false) final List<OrderItemModel>? items,
  }) = _$OrderModelImpl;
  const _OrderModel._() : super._();

  factory _OrderModel.fromJson(Map<String, dynamic> json) =
      _$OrderModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'venue_id')
  String get venueId;
  @override
  @JsonKey(name: 'table_id')
  String get tableId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'order_code')
  String get orderCode;
  @override
  OrderStatus get status;
  @override
  @JsonKey(name: 'payment_method')
  PaymentMethod get paymentMethod;
  @override
  @JsonKey(name: 'payment_status')
  PaymentStatus get paymentStatus;
  @override
  @JsonKey(name: 'payment_reference')
  String? get paymentReference;
  @override
  @JsonKey(name: 'currency_code')
  String get currencyCode;
  @override
  @JsonKey(name: 'subtotal_amount')
  double get subtotalAmount;
  @override
  @JsonKey(name: 'tax_amount')
  double get taxAmount;
  @override
  @JsonKey(name: 'tip_amount')
  double get tipAmount;
  @override
  @JsonKey(name: 'payment_fet_amount')
  int get paymentFetAmount;
  @override
  @JsonKey(name: 'fet_earned')
  int get fetEarned;
  @override
  @JsonKey(name: 'payment_fet_converted_amount')
  double get paymentFetConvertedAmount;
  @override
  @JsonKey(name: 'total_amount')
  double get totalAmount;
  @override
  @JsonKey(name: 'special_instructions')
  String? get specialInstructions;
  @override
  @JsonKey(name: 'estimated_ready_at')
  DateTime? get estimatedReadyAt;
  @override
  @JsonKey(name: 'accepted_at')
  DateTime? get acceptedAt;
  @override
  @JsonKey(name: 'served_at')
  DateTime? get servedAt;
  @override
  @JsonKey(name: 'status_changed_at')
  DateTime? get statusChangedAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt; // Joined data (from expanded queries)
  @override
  @JsonKey(includeToJson: false)
  List<OrderItemModel>? get items;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderItemModel _$OrderItemModelFromJson(Map<String, dynamic> json) {
  return _OrderItemModel.fromJson(json);
}

/// @nodoc
mixin _$OrderItemModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_id')
  String get orderId => throw _privateConstructorUsedError;
  @JsonKey(name: 'menu_item_id')
  String? get menuItemId => throw _privateConstructorUsedError;
  @JsonKey(name: 'item_name_snapshot')
  String get itemNameSnapshot => throw _privateConstructorUsedError;
  @JsonKey(name: 'item_description_snapshot')
  String? get itemDescriptionSnapshot => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  @JsonKey(name: 'unit_price')
  double get unitPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'line_total')
  double get lineTotal => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_code')
  String get currencyCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'add_ons')
  List<Map<String, dynamic>> get addOns => throw _privateConstructorUsedError;
  @JsonKey(name: 'special_instructions')
  String? get specialInstructions => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this OrderItemModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderItemModelCopyWith<OrderItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderItemModelCopyWith<$Res> {
  factory $OrderItemModelCopyWith(
    OrderItemModel value,
    $Res Function(OrderItemModel) then,
  ) = _$OrderItemModelCopyWithImpl<$Res, OrderItemModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'order_id') String orderId,
    @JsonKey(name: 'menu_item_id') String? menuItemId,
    @JsonKey(name: 'item_name_snapshot') String itemNameSnapshot,
    @JsonKey(name: 'item_description_snapshot') String? itemDescriptionSnapshot,
    int quantity,
    @JsonKey(name: 'unit_price') double unitPrice,
    @JsonKey(name: 'line_total') double lineTotal,
    @JsonKey(name: 'currency_code') String currencyCode,
    @JsonKey(name: 'add_ons') List<Map<String, dynamic>> addOns,
    @JsonKey(name: 'special_instructions') String? specialInstructions,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$OrderItemModelCopyWithImpl<$Res, $Val extends OrderItemModel>
    implements $OrderItemModelCopyWith<$Res> {
  _$OrderItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? menuItemId = freezed,
    Object? itemNameSnapshot = null,
    Object? itemDescriptionSnapshot = freezed,
    Object? quantity = null,
    Object? unitPrice = null,
    Object? lineTotal = null,
    Object? currencyCode = null,
    Object? addOns = null,
    Object? specialInstructions = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            orderId: null == orderId
                ? _value.orderId
                : orderId // ignore: cast_nullable_to_non_nullable
                      as String,
            menuItemId: freezed == menuItemId
                ? _value.menuItemId
                : menuItemId // ignore: cast_nullable_to_non_nullable
                      as String?,
            itemNameSnapshot: null == itemNameSnapshot
                ? _value.itemNameSnapshot
                : itemNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            itemDescriptionSnapshot: freezed == itemDescriptionSnapshot
                ? _value.itemDescriptionSnapshot
                : itemDescriptionSnapshot // ignore: cast_nullable_to_non_nullable
                      as String?,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            unitPrice: null == unitPrice
                ? _value.unitPrice
                : unitPrice // ignore: cast_nullable_to_non_nullable
                      as double,
            lineTotal: null == lineTotal
                ? _value.lineTotal
                : lineTotal // ignore: cast_nullable_to_non_nullable
                      as double,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            addOns: null == addOns
                ? _value.addOns
                : addOns // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>,
            specialInstructions: freezed == specialInstructions
                ? _value.specialInstructions
                : specialInstructions // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderItemModelImplCopyWith<$Res>
    implements $OrderItemModelCopyWith<$Res> {
  factory _$$OrderItemModelImplCopyWith(
    _$OrderItemModelImpl value,
    $Res Function(_$OrderItemModelImpl) then,
  ) = __$$OrderItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'order_id') String orderId,
    @JsonKey(name: 'menu_item_id') String? menuItemId,
    @JsonKey(name: 'item_name_snapshot') String itemNameSnapshot,
    @JsonKey(name: 'item_description_snapshot') String? itemDescriptionSnapshot,
    int quantity,
    @JsonKey(name: 'unit_price') double unitPrice,
    @JsonKey(name: 'line_total') double lineTotal,
    @JsonKey(name: 'currency_code') String currencyCode,
    @JsonKey(name: 'add_ons') List<Map<String, dynamic>> addOns,
    @JsonKey(name: 'special_instructions') String? specialInstructions,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$OrderItemModelImplCopyWithImpl<$Res>
    extends _$OrderItemModelCopyWithImpl<$Res, _$OrderItemModelImpl>
    implements _$$OrderItemModelImplCopyWith<$Res> {
  __$$OrderItemModelImplCopyWithImpl(
    _$OrderItemModelImpl _value,
    $Res Function(_$OrderItemModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? menuItemId = freezed,
    Object? itemNameSnapshot = null,
    Object? itemDescriptionSnapshot = freezed,
    Object? quantity = null,
    Object? unitPrice = null,
    Object? lineTotal = null,
    Object? currencyCode = null,
    Object? addOns = null,
    Object? specialInstructions = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$OrderItemModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        orderId: null == orderId
            ? _value.orderId
            : orderId // ignore: cast_nullable_to_non_nullable
                  as String,
        menuItemId: freezed == menuItemId
            ? _value.menuItemId
            : menuItemId // ignore: cast_nullable_to_non_nullable
                  as String?,
        itemNameSnapshot: null == itemNameSnapshot
            ? _value.itemNameSnapshot
            : itemNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        itemDescriptionSnapshot: freezed == itemDescriptionSnapshot
            ? _value.itemDescriptionSnapshot
            : itemDescriptionSnapshot // ignore: cast_nullable_to_non_nullable
                  as String?,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        unitPrice: null == unitPrice
            ? _value.unitPrice
            : unitPrice // ignore: cast_nullable_to_non_nullable
                  as double,
        lineTotal: null == lineTotal
            ? _value.lineTotal
            : lineTotal // ignore: cast_nullable_to_non_nullable
                  as double,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        addOns: null == addOns
            ? _value._addOns
            : addOns // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>,
        specialInstructions: freezed == specialInstructions
            ? _value.specialInstructions
            : specialInstructions // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderItemModelImpl extends _OrderItemModel {
  const _$OrderItemModelImpl({
    required this.id,
    @JsonKey(name: 'order_id') required this.orderId,
    @JsonKey(name: 'menu_item_id') this.menuItemId,
    @JsonKey(name: 'item_name_snapshot') required this.itemNameSnapshot,
    @JsonKey(name: 'item_description_snapshot') this.itemDescriptionSnapshot,
    required this.quantity,
    @JsonKey(name: 'unit_price') required this.unitPrice,
    @JsonKey(name: 'line_total') required this.lineTotal,
    @JsonKey(name: 'currency_code') required this.currencyCode,
    @JsonKey(name: 'add_ons')
    final List<Map<String, dynamic>> addOns = const <Map<String, dynamic>>[],
    @JsonKey(name: 'special_instructions') this.specialInstructions,
    @JsonKey(name: 'created_at') this.createdAt,
  }) : _addOns = addOns,
       super._();

  factory _$OrderItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderItemModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'order_id')
  final String orderId;
  @override
  @JsonKey(name: 'menu_item_id')
  final String? menuItemId;
  @override
  @JsonKey(name: 'item_name_snapshot')
  final String itemNameSnapshot;
  @override
  @JsonKey(name: 'item_description_snapshot')
  final String? itemDescriptionSnapshot;
  @override
  final int quantity;
  @override
  @JsonKey(name: 'unit_price')
  final double unitPrice;
  @override
  @JsonKey(name: 'line_total')
  final double lineTotal;
  @override
  @JsonKey(name: 'currency_code')
  final String currencyCode;
  final List<Map<String, dynamic>> _addOns;
  @override
  @JsonKey(name: 'add_ons')
  List<Map<String, dynamic>> get addOns {
    if (_addOns is EqualUnmodifiableListView) return _addOns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_addOns);
  }

  @override
  @JsonKey(name: 'special_instructions')
  final String? specialInstructions;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'OrderItemModel(id: $id, orderId: $orderId, menuItemId: $menuItemId, itemNameSnapshot: $itemNameSnapshot, itemDescriptionSnapshot: $itemDescriptionSnapshot, quantity: $quantity, unitPrice: $unitPrice, lineTotal: $lineTotal, currencyCode: $currencyCode, addOns: $addOns, specialInstructions: $specialInstructions, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.menuItemId, menuItemId) ||
                other.menuItemId == menuItemId) &&
            (identical(other.itemNameSnapshot, itemNameSnapshot) ||
                other.itemNameSnapshot == itemNameSnapshot) &&
            (identical(
                  other.itemDescriptionSnapshot,
                  itemDescriptionSnapshot,
                ) ||
                other.itemDescriptionSnapshot == itemDescriptionSnapshot) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.unitPrice, unitPrice) ||
                other.unitPrice == unitPrice) &&
            (identical(other.lineTotal, lineTotal) ||
                other.lineTotal == lineTotal) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            const DeepCollectionEquality().equals(other._addOns, _addOns) &&
            (identical(other.specialInstructions, specialInstructions) ||
                other.specialInstructions == specialInstructions) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    orderId,
    menuItemId,
    itemNameSnapshot,
    itemDescriptionSnapshot,
    quantity,
    unitPrice,
    lineTotal,
    currencyCode,
    const DeepCollectionEquality().hash(_addOns),
    specialInstructions,
    createdAt,
  );

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderItemModelImplCopyWith<_$OrderItemModelImpl> get copyWith =>
      __$$OrderItemModelImplCopyWithImpl<_$OrderItemModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderItemModelImplToJson(this);
  }
}

abstract class _OrderItemModel extends OrderItemModel {
  const factory _OrderItemModel({
    required final String id,
    @JsonKey(name: 'order_id') required final String orderId,
    @JsonKey(name: 'menu_item_id') final String? menuItemId,
    @JsonKey(name: 'item_name_snapshot') required final String itemNameSnapshot,
    @JsonKey(name: 'item_description_snapshot')
    final String? itemDescriptionSnapshot,
    required final int quantity,
    @JsonKey(name: 'unit_price') required final double unitPrice,
    @JsonKey(name: 'line_total') required final double lineTotal,
    @JsonKey(name: 'currency_code') required final String currencyCode,
    @JsonKey(name: 'add_ons') final List<Map<String, dynamic>> addOns,
    @JsonKey(name: 'special_instructions') final String? specialInstructions,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$OrderItemModelImpl;
  const _OrderItemModel._() : super._();

  factory _OrderItemModel.fromJson(Map<String, dynamic> json) =
      _$OrderItemModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'order_id')
  String get orderId;
  @override
  @JsonKey(name: 'menu_item_id')
  String? get menuItemId;
  @override
  @JsonKey(name: 'item_name_snapshot')
  String get itemNameSnapshot;
  @override
  @JsonKey(name: 'item_description_snapshot')
  String? get itemDescriptionSnapshot;
  @override
  int get quantity;
  @override
  @JsonKey(name: 'unit_price')
  double get unitPrice;
  @override
  @JsonKey(name: 'line_total')
  double get lineTotal;
  @override
  @JsonKey(name: 'currency_code')
  String get currencyCode;
  @override
  @JsonKey(name: 'add_ons')
  List<Map<String, dynamic>> get addOns;
  @override
  @JsonKey(name: 'special_instructions')
  String? get specialInstructions;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderItemModelImplCopyWith<_$OrderItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
