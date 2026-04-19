import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../features/wallet/data/wallet_gateway.dart';
import '../models/marketplace_model.dart';
import '../providers/auth_provider.dart';
import 'wallet_service.dart';

final marketplaceOffersProvider =
    FutureProvider.autoDispose<List<MarketplaceOffer>>((ref) async {
      return ref.read(walletGatewayProvider).getMarketplaceOffers();
    });

final marketplaceRedemptionsProvider =
    FutureProvider.autoDispose<List<MarketplaceRedemption>>((ref) async {
      ref.watch(authStateProvider);
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId == null) return const [];
      return ref.read(walletGatewayProvider).getMarketplaceRedemptions(userId);
    });

class MarketplaceService {
  MarketplaceService(this.ref, this._gateway);

  final Ref ref;
  final WalletGateway _gateway;

  Future<MarketplaceRedeemResult> redeemOffer(String offerId) async {
    try {
      final parsed = await _gateway.redeemOffer(offerId);

      ref.invalidate(marketplaceOffersProvider);
      ref.invalidate(marketplaceRedemptionsProvider);
      ref.invalidate(walletServiceProvider);
      ref.invalidate(transactionServiceProvider);
      return parsed;
    } catch (error, stack) {
      final failure = mapExceptionToFailure(error, stack);
      AppLogger.w('Reward redemption failed: ${failure.message}');
      throw failure;
    }
  }
}

final marketplaceServiceProvider = Provider<MarketplaceService>(
  (ref) => MarketplaceService(ref, ref.read(walletGatewayProvider)),
);
