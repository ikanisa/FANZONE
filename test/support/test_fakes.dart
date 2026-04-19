import 'dart:async';

import 'package:fanzone/models/pool.dart';
import 'package:fanzone/models/wallet.dart';
import 'package:fanzone/services/pool_service.dart';
import 'package:fanzone/services/wallet_service.dart';

class FakeWalletService extends WalletService {
  FakeWalletService(this.balance);

  final int balance;

  @override
  FutureOr<int> build() => balance;
}

class FakeTransactionService extends TransactionService {
  FakeTransactionService(this.transactions);

  final List<WalletTransaction> transactions;

  @override
  FutureOr<List<WalletTransaction>> build() => transactions;
}

class FakePoolService extends PoolService {
  FakePoolService(this.pools);

  final List<ScorePool> pools;

  @override
  FutureOr<List<ScorePool>> build() => pools;
}

class FakeMyEntries extends MyEntries {
  FakeMyEntries(this.entries);

  final List<PoolEntry> entries;

  @override
  FutureOr<List<PoolEntry>> build() => entries;
}
