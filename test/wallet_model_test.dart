import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/wallet.dart';

void main() {
  group('WalletTransaction', () {
    test('constructs with required fields', () {
      final tx = WalletTransaction(
        id: 'tx-001',
        title: 'Prediction reward',
        amount: 500,
        type: 'earn',
        date: DateTime(2026, 4, 18),
        dateStr: '2h ago',
      );

      expect(tx.id, 'tx-001');
      expect(tx.title, 'Prediction reward');
      expect(tx.amount, 500);
      expect(tx.type, 'earn');
      expect(tx.dateStr, '2h ago');
    });

    test('fromJson round-trip', () {
      final json = {
        'id': 'tx-002',
        'title': 'FET sent',
        'amount': 100,
        'type': 'transfer_sent',
        'date': '2026-04-18T12:00:00.000',
        'dateStr': '1d ago',
      };

      final tx = WalletTransaction.fromJson(json);
      expect(tx.id, 'tx-002');
      expect(tx.amount, 100);
      expect(tx.type, 'transfer_sent');

      final roundTrip = WalletTransaction.fromJson(tx.toJson());
      expect(roundTrip, tx);
    });

    test('equality', () {
      final a = WalletTransaction(
        id: 'same',
        title: 'Test',
        amount: 50,
        type: 'earn',
        date: DateTime(2026, 1, 1),
        dateStr: 'now',
      );
      final b = WalletTransaction(
        id: 'same',
        title: 'Test',
        amount: 50,
        type: 'earn',
        date: DateTime(2026, 1, 1),
        dateStr: 'now',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality on different amount', () {
      final a = WalletTransaction(
        id: 'tx',
        title: 'T',
        amount: 50,
        type: 'earn',
        date: DateTime(2026),
        dateStr: '',
      );
      final b = WalletTransaction(
        id: 'tx',
        title: 'T',
        amount: 100,
        type: 'earn',
        date: DateTime(2026),
        dateStr: '',
      );
      expect(a, isNot(b));
    });
  });
}
