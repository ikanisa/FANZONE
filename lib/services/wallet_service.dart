import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/gateway_providers.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/failures.dart';
import '../core/logging/app_logger.dart';
import '../features/wallet/data/wallet_gateway.dart';
import '../models/wallet.dart';
import '../providers/auth_provider.dart';
import 'product_analytics_service.dart';

part 'wallet_service.g.dart';

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
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      throw const AuthFailure();
    }

    if (amount <= 0) {
      throw const ValidationFailure(
        message: 'Amount must be greater than zero',
        code: 'invalid_amount',
      );
    }

    if (!RegExp(r'^\d{6}$').hasMatch(fanId)) {
      throw const ValidationFailure(
        message: 'Fan ID must be exactly 6 digits',
        code: 'invalid_fan_id',
      );
    }

    state = const AsyncValue.loading();

    try {
      await ref
          .read(walletGatewayProvider)
          .transferByFanId(
            WalletTransferByFanIdDto(fanId: fanId, amount: amount),
          );

      ref.invalidateSelf();
      ref.invalidate(transactionServiceProvider);
      ProductAnalytics.walletAction(action: 'transfer_sent', amountFet: amount);
    } catch (error, stack) {
      final failure = mapExceptionToFailure(error, stack);
      AppLogger.w('Transfer by Fan ID failed: ${failure.message}');
      state = AsyncValue.error(failure, stack);
      throw failure;
    }
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
