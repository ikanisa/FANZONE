import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/ordering/providers/order_provider.dart';
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

    test(
      'customer payment submission is only available before staff confirms',
      () {
        OrderModel buildOrder({
          required PaymentMethod method,
          required PaymentStatus paymentStatus,
          OrderStatus status = OrderStatus.received,
        }) {
          return OrderModel.fromJson({
            'id': 'order_1',
            'venue_id': 'venue_1',
            'table_id': 'table_1',
            'user_id': 'user_1',
            'order_code': 'FZ-1001',
            'status': status.name,
            'payment_method': method.name,
            'payment_status': paymentStatus == PaymentStatus.paymentSubmitted
                ? 'payment_submitted'
                : paymentStatus.name,
            'currency_code': 'EUR',
            'subtotal_amount': 10,
            'tax_amount': 0,
            'tip_amount': 0,
            'payment_fet_amount': 0,
            'fet_earned': 0,
            'payment_fet_converted_amount': 0,
            'total_amount': 10,
          });
        }

        expect(
          canSubmitPaymentForOrder(
            buildOrder(
              method: PaymentMethod.momo,
              paymentStatus: PaymentStatus.pending,
            ),
          ),
          isTrue,
        );
        expect(
          canSubmitPaymentForOrder(
            buildOrder(
              method: PaymentMethod.revolut,
              paymentStatus: PaymentStatus.unpaid,
            ),
          ),
          isTrue,
        );
        expect(
          canSubmitPaymentForOrder(
            buildOrder(
              method: PaymentMethod.cash,
              paymentStatus: PaymentStatus.pending,
            ),
          ),
          isFalse,
        );
        expect(
          canSubmitPaymentForOrder(
            buildOrder(
              method: PaymentMethod.momo,
              paymentStatus: PaymentStatus.paymentSubmitted,
            ),
          ),
          isFalse,
        );
        expect(
          canSubmitPaymentForOrder(
            buildOrder(
              method: PaymentMethod.momo,
              paymentStatus: PaymentStatus.pending,
              status: OrderStatus.cancelled,
            ),
          ),
          isFalse,
        );
      },
    );

    test('payment status stays separate from service status', () {
      final servedButSubmitted = OrderModel.fromJson({
        'id': 'order_1',
        'venue_id': 'venue_1',
        'table_id': 'table_1',
        'user_id': 'user_1',
        'order_code': 'FZ-1001',
        'status': 'served',
        'payment_method': 'momo',
        'payment_status': 'payment_submitted',
        'currency_code': 'EUR',
        'subtotal_amount': 10,
        'tax_amount': 0,
        'tip_amount': 0,
        'payment_fet_amount': 0,
        'fet_earned': 0,
        'payment_fet_converted_amount': 0,
        'total_amount': 10,
      });

      expect(servedButSubmitted.status, OrderStatus.served);
      expect(servedButSubmitted.paymentStatus, PaymentStatus.paymentSubmitted);
      expect(servedButSubmitted.isPaid, isFalse);
      expect(canSubmitPaymentForOrder(servedButSubmitted), isFalse);

      final paidButPreparing = servedButSubmitted.copyWith(
        status: OrderStatus.preparing,
        paymentStatus: PaymentStatus.paid,
      );

      expect(paidButPreparing.status, OrderStatus.preparing);
      expect(paidButPreparing.paymentStatus, PaymentStatus.paid);
      expect(paidButPreparing.isPaid, isTrue);
    });
  });
}
