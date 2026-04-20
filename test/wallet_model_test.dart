import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/wallet.dart';

void main() {
  group('WalletTransaction', () {
    test('constructs with required fields', () {
      final tx = WalletTransaction(
        id: 'tx-001',
        title: 'Challenge payout',
        amount: 500,
        type: 'earn',
        date: DateTime(2026, 4, 18),
        dateStr: '2h ago',
      );

      expect(tx.id, 'tx-001');
      expect(tx.title, 'Challenge payout');
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

  group('FanClub', () {
    test('constructs with required fields', () {
      const club = FanClub(
        id: 'fc-001',
        name: 'Arsenal Supporters',
        members: 1500,
        totalPool: 25000,
        crest: '🔴',
        league: 'Premier League',
        rank: 1,
      );

      expect(club.name, 'Arsenal Supporters');
      expect(club.members, 1500);
      expect(club.rank, 1);
    });

    test('fromJson round-trip', () {
      final json = {
        'id': 'fc-002',
        'name': 'Barcelona FC',
        'members': 2000,
        'totalPool': 50000,
        'crest': '🔵🔴',
        'league': 'La Liga',
        'rank': 2,
      };

      final club = FanClub.fromJson(json);
      expect(club.id, 'fc-002');
      expect(club.totalPool, 50000);

      final roundTrip = FanClub.fromJson(club.toJson());
      expect(roundTrip, club);
    });

    test('equality', () {
      const a = FanClub(
        id: 'fc',
        name: 'X',
        members: 10,
        totalPool: 100,
        crest: '⚽',
        league: 'L',
        rank: 1,
      );
      const b = FanClub(
        id: 'fc',
        name: 'X',
        members: 10,
        totalPool: 100,
        crest: '⚽',
        league: 'L',
        rank: 1,
      );
      expect(a, b);
    });
  });
}
