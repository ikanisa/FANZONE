import '../../../models/auth_and_user/wallet.dart';
import 'wallet_gateway.dart';

class DevPoolEntryLedgerRow {
  const DevPoolEntryLedgerRow({
    required this.id,
    required this.poolId,
    required this.campId,
    required this.amountFet,
    required this.status,
  });

  final String id;
  final String poolId;
  final String campId;
  final int amountFet;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pool_id': poolId,
      'camp_id': campId,
      'amount_fet': amountFet,
      'status': status,
      'payout_fet': 0,
    };
  }
}

class DevRewardsLedger {
  DevRewardsLedger._();

  static final DevRewardsLedger instance = DevRewardsLedger._();
  static const _initialFet = 250;

  final Map<String, WalletBalance> _balances = <String, WalletBalance>{};
  final Map<String, List<WalletTransaction>> _transactions =
      <String, List<WalletTransaction>>{};
  final Map<String, DevPoolEntryLedgerRow> _entries =
      <String, DevPoolEntryLedgerRow>{};

  WalletBalance balanceFor(String userId) {
    return _balances.putIfAbsent(
      userId,
      () => const WalletBalance(
        availableFet: _initialFet,
        stakedFet: 0,
        pendingFet: 0,
        spentFet: 0,
        earnedFet: _initialFet,
      ),
    );
  }

  List<WalletTransaction> transactionsFor(String userId) {
    _ensureWelcomeTransaction(userId);
    return [...(_transactions[userId] ?? const <WalletTransaction>[])];
  }

  DevPoolEntryLedgerRow? entryFor({
    required String userId,
    required String poolId,
  }) {
    return _entries[_entryKey(userId, poolId)];
  }

  Set<String> enteredPoolIdsFor(String userId) {
    return _entries.values
        .where((entry) => entry.id.startsWith('dev-entry-$userId-'))
        .where((entry) => entry.status == 'active')
        .map((entry) => entry.poolId)
        .toSet();
  }

  DevPoolEntryLedgerRow stake({
    required String userId,
    required String poolId,
    required String campId,
    required int amountFet,
  }) {
    final existing = entryFor(userId: userId, poolId: poolId);
    if (existing != null) return existing;

    final current = balanceFor(userId);
    if (current.availableFet < amountFet) {
      throw StateError('Insufficient development FET balance.');
    }

    final entry = DevPoolEntryLedgerRow(
      id: 'dev-entry-$userId-$poolId',
      poolId: poolId,
      campId: campId,
      amountFet: amountFet,
      status: 'active',
    );
    _entries[_entryKey(userId, poolId)] = entry;

    _balances[userId] = WalletBalance(
      availableFet: current.availableFet - amountFet,
      stakedFet: current.stakedFet + amountFet,
      pendingFet: current.pendingFet,
      spentFet: current.spentFet + amountFet,
      earnedFet: current.earnedFet,
    );
    _transactions[userId] = [
      WalletTransaction(
        id: 'dev-pool-stake-$poolId',
        title: 'Pool entry',
        amount: amountFet,
        type: 'pool_stake',
        date: DateTime.now(),
        dateStr: 'now',
      ),
      ...transactionsFor(userId),
    ];
    return entry;
  }

  void _ensureWelcomeTransaction(String userId) {
    _transactions.putIfAbsent(
      userId,
      () => <WalletTransaction>[
        WalletTransaction(
          id: 'dev-welcome-$userId',
          title: 'Development rewards balance',
          amount: _initialFet,
          type: 'welcome_credit',
          date: DateTime.now(),
          dateStr: 'now',
        ),
      ],
    );
  }

  String _entryKey(String userId, String poolId) => '$userId::$poolId';
}
