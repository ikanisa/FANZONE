import 'dart:async';

import 'package:fanzone/models/wallet.dart';
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
