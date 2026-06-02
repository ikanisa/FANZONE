import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/features/ordering/data/bell_gateway.dart';
import 'package:fanzone/features/ordering/providers/order_provider.dart';
import 'package:fanzone/features/ordering/screens/order_tracking_screen.dart';
import 'package:fanzone/models/hospitality/bell_request_model.dart';
import 'package:fanzone/models/hospitality/order_model.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('order tracking shows the target hospitality lifecycle', (
    tester,
  ) async {
    final order = _orderWithStatus(OrderStatus.completed);

    await pumpAppScreen(
      tester,
      const OrderTrackingScreen(orderId: 'order_1'),
      overrides: [
        orderRealtimeProvider(
          'order_1',
        ).overrideWith((ref) => Stream.value(order)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Served'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('order tracking maps legacy received status to accepted copy', (
    tester,
  ) async {
    final order = _orderWithStatus(OrderStatus.received);

    await pumpAppScreen(
      tester,
      const OrderTrackingScreen(orderId: 'order_1'),
      overrides: [
        orderRealtimeProvider(
          'order_1',
        ).overrideWith((ref) => Stream.value(order)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Received'), findsNothing);
  });

  testWidgets('order tracking can call staff about the order', (tester) async {
    final order = _orderWithStatus(OrderStatus.preparing);
    final bellGateway = _FakeBellGateway();

    await pumpAppScreen(
      tester,
      const OrderTrackingScreen(orderId: 'order_1'),
      overrides: [
        orderRealtimeProvider(
          'order_1',
        ).overrideWith((ref) => Stream.value(order)),
        bellGatewayProvider.overrideWithValue(bellGateway),
      ],
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Call staff'));
    await tester.pumpAndSettle();

    expect(bellGateway.calls, hasLength(1));
    expect(bellGateway.calls.single.venueId, 'venue_1');
    expect(bellGateway.calls.single.tableId, 'table_1');
    expect(bellGateway.calls.single.message, contains('Order #FZ-1001'));
    expect(find.text('Staff call sent for this order.'), findsOneWidget);
  });
}

class _RingBellCall {
  const _RingBellCall({
    required this.venueId,
    required this.tableId,
    required this.message,
  });

  final String venueId;
  final String tableId;
  final String? message;
}

class _FakeBellGateway implements BellGateway {
  final calls = <_RingBellCall>[];

  @override
  Future<BellRequestModel> ringBell({
    required String venueId,
    required String tableId,
    String? message,
  }) async {
    calls.add(
      _RingBellCall(venueId: venueId, tableId: tableId, message: message),
    );
    return BellRequestModel(
      id: 'bell_1',
      venueId: venueId,
      tableId: tableId,
      userId: 'user_1',
      message: message,
      createdAt: DateTime.utc(2026, 5, 23, 10),
    );
  }

  @override
  Future<void> acknowledgeBell(String bellId) async {}

  @override
  Future<List<BellRequestModel>> getActiveBells(
    String venueId, {
    int limit = 50,
  }) async => const [];

  @override
  RealtimeChannel subscribeToVenueBells(
    String venueId,
    void Function(BellRequestModel bell) onBell,
  ) {
    throw UnimplementedError();
  }
}

OrderModel _orderWithStatus(OrderStatus status) {
  return OrderModel.fromJson({
    'id': 'order_1',
    'venue_id': 'venue_1',
    'table_id': 'table_1',
    'user_id': 'user_1',
    'order_code': 'FZ-1001',
    'status': status.name,
    'payment_method': 'momo',
    'payment_status': 'payment_submitted',
    'currency_code': 'EUR',
    'subtotal_amount': 10,
    'tax_amount': 0,
    'tip_amount': 0,
    'payment_fet_amount': 0,
    'fet_earned': 42,
    'payment_fet_converted_amount': 0,
    'total_amount': 10,
    'created_at': '2026-05-23T10:00:00.000Z',
    'items': [
      {
        'id': 'item_1',
        'order_id': 'order_1',
        'menu_item_id': 'menu_1',
        'item_name_snapshot': 'Test burger',
        'quantity': 1,
        'unit_price': 10,
        'line_total': 10,
        'currency_code': 'EUR',
      },
    ],
  });
}
