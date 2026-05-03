import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/hospitality/order_model.dart';

void main() {
  group('OrderModel', () {
    test('uses ledger-backed FET earned amount from order row', () {
      final order = OrderModel.fromJson({
        'id': 'order_1',
        'venue_id': 'venue_1',
        'table_id': 'table_1',
        'user_id': 'user_1',
        'order_code': 'FZ-1001',
        'status': 'preparing',
        'payment_method': 'momo',
        'payment_status': 'paid',
        'currency_code': 'EUR',
        'subtotal_amount': 10,
        'tax_amount': 0,
        'tip_amount': 0,
        'payment_fet_amount': 0,
        'fet_earned': 42,
        'payment_fet_converted_amount': 0,
        'total_amount': 10,
      });

      expect(order.status, OrderStatus.preparing);
      expect(order.fetEarned, 42);
      expect(order.earnedFetDisplayAmount, 42);
      expect(order.estimatedFetEarned, isNot(42));
    });
  });
}
