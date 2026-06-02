import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/gateway_providers.dart';
import '../core/errors/failures.dart';
import '../features/wallet/data/wallet_gateway.dart';
import '../models/auth_and_user/wallet.dart';
import '../providers/auth_provider.dart';

part 'wallet_service.g.dart';

final walletBalanceProvider = FutureProvider<WalletBalance>((ref) async {
  ref.watch(authStateProvider);

  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) {
    final available = await ref.watch(walletServiceProvider.future);
    return WalletBalance(
      availableFet: available,
      stakedFet: 0,
      pendingFet: 0,
      spentFet: 0,
      earnedFet: 0,
    );
  }

  return ref.read(walletGatewayProvider).getWalletBalance(userId);
});

@riverpod
class WalletService extends _$WalletService {
  @override
  FutureOr<int> build() async {
    ref.watch(authStateProvider);

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return 0;

    return ref.read(walletGatewayProvider).getAvailableBalance(userId);
  }

  Future<void> transferByFanId(String fanId, int amount) async {
    assert(fanId.isNotEmpty || amount >= 0);
    throw const ValidationFailure(
      message:
          'Customer-to-customer FET movement is disabled. FET is a closed-loop rewards ledger.',
      code: 'fet_movement_disabled',
    );
  }
}

@riverpod
class TransactionService extends _$TransactionService {
  @override
  FutureOr<List<WalletTransaction>> build() async {
    ref.watch(authStateProvider);

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return const [];

    return ref.read(walletGatewayProvider).getTransactions(userId);
  }
}
