import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fanzone/core/storage/structured_cache_store.dart';
import 'package:fanzone/features/ordering/data/order_gateway.dart';
import 'package:fanzone/features/ordering/providers/cart_provider.dart';
import 'package:fanzone/features/ordering/providers/order_provider.dart';
import 'package:fanzone/models/hospitality/menu_item_model.dart';
import 'package:fanzone/models/hospitality/order_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fanzone-order-provider-test-',
    );
    await StructuredCacheStore.init(directory: tempDir.path);
  });

  tearDown(() async {
    await StructuredCacheStore.resetForTest();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('OrderPlacementNotifier', () {
    test('does not expose backend exception text in checkout errors', () async {
      final cart = CartNotifier()
        ..addItem(
          const MenuItemModel(
            id: 'menu_1',
            venueId: 'venue_1',
            categoryId: 'cat_1',
            name: 'UAT Burger',
            price: 12,
            currencyCode: 'EUR',
          ),
        );
      final notifier = OrderPlacementNotifier(_ThrowingOrderGateway(), cart);

      final order = await notifier.placeOrder(
        venueId: 'venue_1',
        tableNumber: 'T1',
        paymentMethod: PaymentMethod.cash,
        currencyCode: 'EUR',
      );

      expect(order, isNull);
      expect(notifier.state.status, OrderPlacementStatus.error);
      expect(
        notifier.state.errorMessage,
        'The venue did not receive this order. Check your connection and try again.',
      );
      expect(
        notifier.state.errorMessage,
        isNot(contains('PostgrestException')),
      );
      expect(notifier.state.errorMessage, isNot(contains('service_role')));
      expect(notifier.state.errorMessage, isNot(contains('failed row')));
    });
  });
}

class _ThrowingOrderGateway implements OrderGateway {
  @override
  Future<OrderModel> placeOrder(CreateOrderDto request) {
    throw StateError(
      'PostgrestException(message: failed row includes service_role debug text)',
    );
  }

  @override
  Future<PaymentHandoff> createPaymentHandoff({
    required String orderId,
    required String venueId,
    required PaymentMethod method,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> submitPayment({
    required String orderId,
    required PaymentMethod method,
    String? externalReference,
    String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<OrderModel?> getOrder(String orderId) {
    throw UnimplementedError();
  }

  @override
  Future<List<OrderModel>> getUserOrders(String userId, {int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<List<OrderModel>> getVenueOrders(
    String venueId, {
    List<OrderStatus>? statusFilter,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus, {
    required String note,
    PaymentMethod method = PaymentMethod.cash,
    double? amountReceived,
    String? externalReference,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> spendFetOnOrder({
    required String orderId,
    required int amountFet,
  }) {
    throw UnimplementedError();
  }

  @override
  RealtimeChannel subscribeToOrder(
    String orderId,
    void Function(OrderModel order) onUpdate,
  ) {
    throw UnimplementedError();
  }

  @override
  RealtimeChannel subscribeToVenueOrders(
    String venueId,
    void Function(OrderModel order) onUpdate,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<int> getVenueRedeemedTokens(String venueId) {
    throw UnimplementedError();
  }
}
