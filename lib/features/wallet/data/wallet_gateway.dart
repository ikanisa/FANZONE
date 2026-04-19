import 'package:injectable/injectable.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/marketplace_model.dart';
import '../../../models/wallet.dart';

abstract interface class WalletGateway {
  Future<int> getAvailableBalance(String userId);

  Future<void> transferByFanId(WalletTransferByFanIdDto request);

  Future<List<WalletTransaction>> getTransactions(String userId);

  Future<List<FanClub>> getFanClubs();

  Future<List<CurrencyRateDto>> getCurrencyRates({String baseCurrency});

  Future<String?> guessUserCurrency(String userId);

  Future<String?> getFanId(String userId);

  Future<List<MarketplaceOffer>> getMarketplaceOffers();

  Future<List<MarketplaceRedemption>> getMarketplaceRedemptions(String userId);

  Future<MarketplaceRedeemResult> redeemOffer(String offerId);

  Future<List<FetExchangeRateDto>> getFetExchangeRates();
}

class WalletTransferByFanIdDto {
  const WalletTransferByFanIdDto({required this.fanId, required this.amount});

  final String fanId;
  final int amount;
}

class CurrencyRateDto {
  const CurrencyRateDto({
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    this.source,
    this.updatedAt,
  });

  factory CurrencyRateDto.fromJson(Map<String, dynamic> json) {
    return CurrencyRateDto(
      baseCurrency: json['base_currency']?.toString() ?? 'EUR',
      targetCurrency: json['target_currency']?.toString() ?? 'EUR',
      rate: (json['rate'] as num?)?.toDouble() ?? 1,
      source: json['source']?.toString(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );
  }

  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final String? source;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'base_currency': baseCurrency,
      'target_currency': targetCurrency,
      'rate': rate,
      'source': source,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class FetExchangeRateDto {
  const FetExchangeRateDto({
    required this.currency,
    required this.symbol,
    required this.rate,
  });

  final String currency;
  final String symbol;
  final double rate;
}

@LazySingleton(as: WalletGateway)
class SupabaseWalletGateway implements WalletGateway {
  SupabaseWalletGateway(this._connection);

  final SupabaseConnection _connection;
  final Map<String, int> _localBalances = <String, int>{};
  final Map<String, List<WalletTransaction>> _localTransactions =
      <String, List<WalletTransaction>>{};
  final Map<String, List<MarketplaceRedemption>> _localRedemptions =
      <String, List<MarketplaceRedemption>>{};
  String _activeUserId = 'local-user';

  @override
  Future<int> getAvailableBalance(String userId) async {
    _activeUserId = userId;
    final client = _connection.client;
    if (client == null) {
      return _localBalances.putIfAbsent(userId, () => 420);
    }

    try {
      final row = await client
          .from('fet_wallets')
          .select('available_balance_fet')
          .eq('user_id', userId)
          .maybeSingle();
      final balance = (row?['available_balance_fet'] as num?)?.toInt();
      if (balance != null) {
        _localBalances[userId] = balance;
        return balance;
      }
    } catch (error) {
      AppLogger.d('Failed to load wallet balance: $error');
    }

    return _localBalances.putIfAbsent(userId, () => 420);
  }

  @override
  Future<void> transferByFanId(WalletTransferByFanIdDto request) async {
    final userId = _activeUserId;
    final client = _connection.client;
    if (client != null) {
      try {
        await client.rpc(
          'transfer_fet_by_fan_id',
          params: {
            'p_recipient_fan_id': request.fanId,
            'p_amount_fet': request.amount,
          },
        );
        return;
      } catch (error) {
        AppLogger.d('Failed to transfer by fan id remotely: $error');
      }
    }

    final current = await getAvailableBalance(userId);
    final balanceAfter = (current - request.amount).clamp(0, 100000);
    _localBalances[userId] = balanceAfter;
    _localTransactions[userId] = [
      WalletTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Transfer to ${request.fanId}',
        amount: request.amount,
        type: 'transfer_sent',
        date: DateTime.now(),
        dateStr: 'now',
      ),
      ...(_localTransactions[userId] ?? const <WalletTransaction>[]),
    ];
  }

  @override
  Future<List<WalletTransaction>> getTransactions(String userId) async {
    _activeUserId = userId;
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('fet_wallet_transactions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50);
        final transactions = (rows as List)
            .whereType<Map>()
            .map(
              (row) => WalletTransaction(
                id: row['id']?.toString() ?? '',
                title: row['title']?.toString() ?? 'Wallet activity',
                amount: (row['amount_fet'] as num?)?.toInt() ?? 0,
                type: _transactionTypeFromRow(Map<String, dynamic>.from(row)),
                date:
                    DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                    DateTime.now(),
                dateStr: _relativeDateLabel(
                  DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                ),
              ),
            )
            .toList(growable: false);
        if (transactions.isNotEmpty) {
          _localTransactions[userId] = transactions;
          return transactions;
        }
      } catch (error) {
        AppLogger.d('Failed to load wallet transactions: $error');
      }
    }

    return [
      ...(_localTransactions[userId] ??
          <WalletTransaction>[
            WalletTransaction(
              id: 'tx_1',
              title: 'Challenge payout',
              amount: 120,
              type: 'earn',
              date: DateTime.now().subtract(const Duration(hours: 5)),
              dateStr: '5h ago',
            ),
            WalletTransaction(
              id: 'tx_2',
              title: 'Club contribution',
              amount: 40,
              type: 'spend',
              date: DateTime.now().subtract(const Duration(days: 1)),
              dateStr: '1d ago',
            ),
          ]),
    ];
  }

  @override
  Future<List<FanClub>> getFanClubs() async {
    return const [
      FanClub(
        id: 'liverpool',
        name: 'Liverpool',
        members: 24000,
        totalPool: 125000,
        crest: '',
        league: 'Premier League',
        rank: 1,
      ),
      FanClub(
        id: 'arsenal',
        name: 'Arsenal',
        members: 22000,
        totalPool: 118000,
        crest: '',
        league: 'Premier League',
        rank: 2,
      ),
    ];
  }

  @override
  Future<List<CurrencyRateDto>> getCurrencyRates({
    String baseCurrency = 'EUR',
  }) async {
    final normalizedBase = baseCurrency.trim().toUpperCase();
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('currency_rates')
            .select()
            .eq('base_currency', normalizedBase)
            .order('target_currency');
        final rates = (rows as List)
            .whereType<Map>()
            .map((row) => CurrencyRateDto.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
        if (rates.isNotEmpty) return rates;
      } catch (error) {
        AppLogger.d('Failed to load currency rates: $error');
      }
    }

    if (normalizedBase != 'EUR') return const [];

    final now = DateTime.now();
    return [
      CurrencyRateDto(
        baseCurrency: 'EUR',
        targetCurrency: 'EUR',
        rate: 1,
        source: 'local',
        updatedAt: now,
      ),
      CurrencyRateDto(
        baseCurrency: 'EUR',
        targetCurrency: 'USD',
        rate: 1.09,
        source: 'local',
        updatedAt: now,
      ),
      CurrencyRateDto(
        baseCurrency: 'EUR',
        targetCurrency: 'GBP',
        rate: 0.86,
        source: 'local',
        updatedAt: now,
      ),
      CurrencyRateDto(
        baseCurrency: 'EUR',
        targetCurrency: 'RWF',
        rate: 1450,
        source: 'local',
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<String?> guessUserCurrency(String userId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final row = await client
            .from('profiles')
            .select('currency_code')
            .eq('id', userId)
            .maybeSingle();
        final code = row?['currency_code']?.toString();
        if (code != null && code.isNotEmpty) return code;
      } catch (error) {
        AppLogger.d('Failed to load user currency: $error');
      }
    }

    if (userId.toLowerCase().contains('rw')) return 'RWF';
    if (userId.toLowerCase().contains('uk')) return 'GBP';
    return 'EUR';
  }

  @override
  Future<String?> getFanId(String userId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final row = await client
            .from('profiles')
            .select('fan_id')
            .eq('id', userId)
            .maybeSingle();
        final fanId = row?['fan_id']?.toString();
        if (fanId != null && fanId.isNotEmpty) return fanId;
      } catch (error) {
        AppLogger.d('Failed to load fan id: $error');
      }
    }

    final digits = userId.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.padLeft(6, '0').substring(0, 6);
  }

  @override
  Future<List<MarketplaceOffer>> getMarketplaceOffers() async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('marketplace_offers')
            .select('*, partner:marketplace_partners(*)')
            .eq('is_active', true)
            .order('sort_order');
        final offers = (rows as List)
            .whereType<Map>()
            .map(
              (row) => MarketplaceOffer.fromRow(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
        if (offers.isNotEmpty) return offers;
      } catch (error) {
        AppLogger.d('Failed to load marketplace offers: $error');
      }
    }

    return const [
      MarketplaceOffer(
        id: 'offer_1',
        partnerId: 'partner_1',
        partnerName: 'Matchday Merch',
        title: 'Official scarf voucher',
        description: 'Redeem a digital voucher for official club merchandise.',
        category: 'merch',
        costFet: 120,
        deliveryType: 'voucher',
        isActive: true,
        originalValue: '€20',
      ),
      MarketplaceOffer(
        id: 'offer_2',
        partnerId: 'partner_2',
        partnerName: 'Fan Lounge',
        title: 'Premium watch party pass',
        description: 'Unlock one premium live watch party entry.',
        category: 'experience',
        costFet: 180,
        deliveryType: 'code',
        isActive: true,
        originalValue: '€30',
      ),
    ];
  }

  @override
  Future<List<MarketplaceRedemption>> getMarketplaceRedemptions(
    String userId,
  ) async {
    _activeUserId = userId;
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('marketplace_redemptions')
            .select('*, offer:marketplace_offers(*, partner:marketplace_partners(*))')
            .eq('user_id', userId)
            .order('redeemed_at', ascending: false);
        final redemptions = (rows as List)
            .whereType<Map>()
            .map(
              (row) =>
                  MarketplaceRedemption.fromRow(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
        if (redemptions.isNotEmpty) {
          _localRedemptions[userId] = redemptions;
          return redemptions;
        }
      } catch (error) {
        AppLogger.d('Failed to load redemptions: $error');
      }
    }

    return [...(_localRedemptions[userId] ?? const <MarketplaceRedemption>[])];
  }

  @override
  Future<MarketplaceRedeemResult> redeemOffer(String offerId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final response = await client.rpc(
          'redeem_offer',
          params: {'p_offer_id': offerId},
        );
        if (response is Map<String, dynamic>) {
          return MarketplaceRedeemResult.fromJson(response);
        }
        if (response is Map) {
          return MarketplaceRedeemResult.fromJson(
            Map<String, dynamic>.from(response),
          );
        }
      } catch (error) {
        AppLogger.d('Failed to redeem offer remotely: $error');
      }
    }

    final userId = _activeUserId;
    final offers = await getMarketplaceOffers();
    MarketplaceOffer? selected;
    for (final offer in offers) {
      if (offer.id == offerId) {
        selected = offer;
        break;
      }
    }
    if (selected == null) {
      return const MarketplaceRedeemResult(
        status: 'pending',
        redemptionId: '',
        deliveryType: 'voucher',
        balanceAfter: 0,
      );
    }

    final currentBalance = await getAvailableBalance(userId);
    final balanceAfter = (currentBalance - selected.costFet).clamp(0, 100000);
    _localBalances[userId] = balanceAfter;

    final redemption = MarketplaceRedemption(
      id: 'redemption_${DateTime.now().millisecondsSinceEpoch}',
      offerId: selected.id,
      title: selected.title,
      partnerName: selected.partnerName,
      costFet: selected.costFet,
      deliveryType: selected.deliveryType,
      status: 'ready',
      redeemedAt: DateTime.now(),
      deliveryValue: 'FZ-${DateTime.now().millisecondsSinceEpoch}',
      imageUrl: selected.imageUrl,
    );

    _localRedemptions[userId] = [
      redemption,
      ...(_localRedemptions[userId] ?? const <MarketplaceRedemption>[]),
    ];

    return MarketplaceRedeemResult(
      status: 'ready',
      redemptionId: redemption.id,
      deliveryType: redemption.deliveryType,
      balanceAfter: balanceAfter,
      deliveryValue: redemption.deliveryValue,
    );
  }

  @override
  Future<List<FetExchangeRateDto>> getFetExchangeRates() async {
    return const [
      FetExchangeRateDto(currency: 'EUR', symbol: '€', rate: 0.01),
      FetExchangeRateDto(currency: 'USD', symbol: '\$', rate: 0.011),
      FetExchangeRateDto(currency: 'RWF', symbol: 'FRw', rate: 14.5),
    ];
  }

  String _transactionTypeFromRow(Map<String, dynamic> row) {
    final type = row['tx_type']?.toString() ?? '';
    final direction = row['direction']?.toString() ?? '';
    if (type == 'transfer' && direction == 'debit') return 'transfer_sent';
    if (type == 'transfer' && direction == 'credit') return 'transfer_received';
    if (direction == 'credit') return 'earn';
    return 'spend';
  }

  String _relativeDateLabel(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
