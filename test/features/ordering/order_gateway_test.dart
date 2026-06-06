import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/ordering/data/order_gateway.dart';
import 'package:fanzone/models/hospitality/order_model.dart';

void main() {
  group('buildOrderMarkPaidBody', () {
    test('builds the audited manual paid confirmation payload', () {
      final body = buildOrderMarkPaidBody(
        orderId: '00000000-0000-4000-8000-000000000101',
        method: PaymentMethod.momo,
        note: ' Customer showed MoMo confirmation ',
        amountReceived: 12.5,
        externalReference: ' MOMO-123 ',
      );

      expect(body, {
        'order_id': '00000000-0000-4000-8000-000000000101',
        'payment_method': 'momo',
        'note': 'Customer showed MoMo confirmation',
        'amount_received': 12.5,
        'external_reference': 'MOMO-123',
      });
    });

    test('requires an actor note for manual paid confirmation', () {
      expect(
        () => buildOrderMarkPaidBody(
          orderId: '00000000-0000-4000-8000-000000000101',
          note: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('does not allow card as an MVP manual confirmation method', () {
      expect(
        () => buildOrderMarkPaidBody(
          orderId: '00000000-0000-4000-8000-000000000101',
          method: PaymentMethod.card,
          note: 'Card confirmation should not be available',
        ),
        throwsArgumentError,
      );
    });
  });
}
