import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../core/network/supabase_provider.dart';
import '../main.dart' show supabaseInitialized;
import '../models/marketplace_model.dart';
import '../providers/auth_provider.dart';
import 'wallet_service.dart';

final marketplaceOffersProvider =
    FutureProvider.autoDispose<List<MarketplaceOffer>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      final data = await client
          .from('marketplace_offers')
          .select(
            'id, partner_id, title, description, image_url, category, cost_fet, '
            'original_value, delivery_type, stock, is_active, terms, valid_until, '
            'partner:marketplace_partners(name, logo_url)',
          )
          .eq('is_active', true)
          .order('sort_order')
          .order('cost_fet')
          .timeout(supabaseTimeout);

      return (data as List)
          .map(
            (row) =>
                MarketplaceOffer.fromRow(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    });

final marketplaceRedemptionsProvider =
    FutureProvider.autoDispose<List<MarketplaceRedemption>>((ref) async {
      ref.watch(authStateProvider);

      if (!supabaseInitialized) return const [];

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const [];

      final data = await client
          .from('marketplace_redemptions')
          .select(
            'id, offer_id, cost_fet, delivery_type, delivery_value, status, '
            'redeemed_at, expires_at, '
            'offer:marketplace_offers(title, image_url, '
            'partner:marketplace_partners(name))',
          )
          .eq('user_id', userId)
          .order('redeemed_at', ascending: false)
          .limit(50);

      return (data as List)
          .map(
            (row) => MarketplaceRedemption.fromRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    });

class MarketplaceService {
  MarketplaceService(this.ref);

  final Ref ref;

  Future<MarketplaceRedeemResult> redeemOffer(String offerId) async {
    if (!supabaseInitialized) {
      throw StateError('Supabase not initialized');
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Not authenticated');
    }

    try {
      final result = await client.rpc(
        'redeem_offer',
        params: {'p_offer_id': offerId},
      );

      final parsed = MarketplaceRedeemResult.fromJson(
        Map<String, dynamic>.from((result as Map).cast<String, dynamic>()),
      );

      ref.invalidate(marketplaceOffersProvider);
      ref.invalidate(marketplaceRedemptionsProvider);
      ref.invalidate(walletServiceProvider);
      ref.invalidate(transactionServiceProvider);
      return parsed;
    } on PostgrestException catch (e) {
      AppLogger.d('Reward redemption failed: ${e.message}');
      throw StateError(e.message);
    }
  }
}

final marketplaceServiceProvider = Provider<MarketplaceService>(
  (ref) => MarketplaceService(ref),
);
