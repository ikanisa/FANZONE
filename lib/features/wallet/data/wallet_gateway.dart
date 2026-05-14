import '../../../config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/config/platform_feature_access.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/auth_and_user/wallet.dart';

abstract interface class WalletGateway {
  Future<WalletBalance> getWalletBalance(String userId);

  Future<int> getAvailableBalance(String userId);

  Future<void> transferByFanId(WalletTransferByFanIdDto request);

  Future<List<WalletTransaction>> getTransactions(String userId);

  Future<List<CurrencyRateDto>> getCurrencyRates({String baseCurrency});

  Future<String?> guessUserCurrency(String userId);

  Future<String?> getFanId(String userId);

  Future<List<FetExchangeRateDto>> getFetExchangeRates();
}

class WalletTransferByFanIdDto {
  const WalletTransferByFanIdDto({required this.fanId, required this.amount});

  final String fanId;
  final int amount;
}

class WalletBalance {
  const WalletBalance({
    required this.availableFet,
    required this.stakedFet,
    required this.pendingFet,
    required this.spentFet,
    required this.earnedFet,
  });

  const WalletBalance.empty()
    : availableFet = 0,
      stakedFet = 0,
      pendingFet = 0,
      spentFet = 0,
      earnedFet = 0;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      availableFet: _intFromJson(json, const [
        'available_fet',
        'available_balance_fet',
      ]),
      stakedFet: _intFromJson(json, const ['staked_fet', 'staked_balance_fet']),
      pendingFet: _intFromJson(json, const [
        'pending_fet',
        'pending_balance_fet',
      ]),
      spentFet: _intFromJson(json, const ['spent_fet']),
      earnedFet: _intFromJson(json, const ['earned_fet']),
    );
  }

  final int availableFet;
  final int stakedFet;
  final int pendingFet;
  final int spentFet;
  final int earnedFet;

  static int _intFromJson(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }
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

class SupabaseWalletGateway implements WalletGateway {
  SupabaseWalletGateway(this._connection);

  final SupabaseConnection _connection;
  final Map<String, int> _localBalances = <String, int>{};
  final Map<String, WalletBalance> _localWalletBalances =
      <String, WalletBalance>{};
  final Map<String, List<WalletTransaction>> _localTransactions =
      <String, List<WalletTransaction>>{};

  @override
  Future<WalletBalance> getWalletBalance(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return _cachedWalletBalanceOrThrow(userId);
    }

    try {
      final response = await client.rpc(
        'get_wallet_balance',
        params: {'p_user_id': userId},
      );
      final balance = WalletBalance.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      _localWalletBalances[userId] = balance;
      _localBalances[userId] = balance.availableFet;
      return balance;
    } catch (error) {
      AppLogger.d('Failed to load wallet state: $error');
    }

    return _cachedWalletBalanceOrThrow(userId);
  }

  @override
  Future<int> getAvailableBalance(String userId) async {
    return getWalletBalance(userId).then((balance) => balance.availableFet);
  }

  @override
  Future<void> transferByFanId(WalletTransferByFanIdDto request) async {
    if (AppConfig.isReviewMode) {
      throw StateError(
        'FET transfers are disabled in the FANZONE review PWA. Use staging-safe test data for browser review.',
      );
    }
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('FET transfer');
    }
    if (_connection.currentUser?.isAnonymous ?? false) {
      throw StateError(
        'Verify your WhatsApp number before sending FET to another fan.',
      );
    }

    assertRuntimePlatformFeatureActionAvailable(
      'wallet',
      fallbackMessage: 'Wallet transfers are unavailable right now.',
    );

    try {
      await client.rpc(
        'transfer_fet_by_fan_id',
        params: {
          'p_recipient_fan_id': request.fanId,
          'p_amount_fet': request.amount,
        },
      );
    } catch (error) {
      AppLogger.d('Failed to transfer by fan id remotely: $error');
      rethrow;
    }
  }

  @override
  Future<List<WalletTransaction>> getTransactions(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return _cachedTransactionsOrThrow(userId);
    }

    try {
      final rows = await client
          .from('fet_wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      final transactions = (rows as List)
          .whereType<Map>()
          .where(_isUserVisibleTransaction)
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
      _localTransactions[userId] = transactions;
      return transactions;
    } catch (error) {
      AppLogger.d('Failed to load wallet transactions: $error');
    }

    return _cachedTransactionsOrThrow(userId);
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
            .map(
              (row) => CurrencyRateDto.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
        return rates;
      } catch (error) {
        AppLogger.d('Failed to load currency rates: $error');
      }
    }

    return const <CurrencyRateDto>[];
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

        final guess = await client.rpc(
          'guess_user_currency',
          params: {'p_user_id': userId},
        );
        final guessedCode = (guess is Map)
            ? guess['currency_code']?.toString()
            : null;
        if (guessedCode != null && guessedCode.isNotEmpty) {
          return guessedCode;
        }
      } catch (error) {
        AppLogger.d('Failed to load user currency: $error');
      }
    }

    return null;
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

    return null;
  }

  @override
  Future<List<FetExchangeRateDto>> getFetExchangeRates() async {
    final client = _connection.client;
    if (client != null) {
      try {
        final pegRow = await client
            .from('app_config_remote')
            .select('value')
            .eq('key', 'fet_per_eur')
            .maybeSingle();
        final fetPerEur = _parsePositiveNumber(pegRow?['value']);
        if (fetPerEur == null) {
          return const <FetExchangeRateDto>[];
        }

        final fetToEurRate = 1 / fetPerEur;
        final rows = await client
            .from('currency_rates')
            .select('target_currency, rate')
            .eq('base_currency', 'EUR')
            .order('target_currency');
        final metadataRows = await client
            .from('currency_display_metadata')
            .select('currency_code, symbol');
        final symbols = <String, String>{
          for (final row in (metadataRows as List).whereType<Map>())
            row['currency_code']?.toString().toUpperCase() ?? '':
                row['symbol']?.toString() ?? '',
        }..remove('');
        final rates = <FetExchangeRateDto>[
          FetExchangeRateDto(
            currency: 'EUR',
            symbol: symbols['EUR'] ?? 'EUR',
            rate: fetToEurRate,
          ),
        ];
        for (final row in (rows as List).whereType<Map>()) {
          final target = row['target_currency']?.toString();
          final eurRate = (row['rate'] as num?)?.toDouble();
          if (target == null || eurRate == null || target == 'EUR') continue;
          rates.add(
            FetExchangeRateDto(
              currency: target,
              symbol: symbols[target.toUpperCase()] ?? target,
              rate: fetToEurRate * eurRate,
            ),
          );
        }
        return rates;
      } catch (error) {
        AppLogger.d('Failed to load FET exchange rates: $error');
      }
    }

    return const <FetExchangeRateDto>[];
  }

  double? _parsePositiveNumber(dynamic rawValue) {
    if (rawValue is num) {
      final value = rawValue.toDouble();
      if (value > 0) return value;
    }
    if (rawValue is String) {
      final parsed = double.tryParse(rawValue.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  int _cachedBalance(String userId) {
    return _localBalances[userId] ?? 0;
  }

  WalletBalance _cachedWalletBalance(String userId) {
    return _localWalletBalances[userId] ??
        WalletBalance(
          availableFet: _cachedBalance(userId),
          stakedFet: 0,
          pendingFet: 0,
          spentFet: 0,
          earnedFet: 0,
        );
  }

  WalletBalance _cachedWalletBalanceOrThrow(String userId) {
    if (_localWalletBalances.containsKey(userId) ||
        _localBalances.containsKey(userId)) {
      return _cachedWalletBalance(userId);
    }
    _throwUnavailable('Wallet');
  }

  List<WalletTransaction> _cachedTransactions(String userId) {
    return [...(_localTransactions[userId] ?? const <WalletTransaction>[])];
  }

  List<WalletTransaction> _cachedTransactionsOrThrow(String userId) {
    if (_localTransactions.containsKey(userId)) {
      return _cachedTransactions(userId);
    }
    _throwUnavailable('Wallet history');
  }

  Never _throwUnavailable(String action) {
    throw StateError('$action is unavailable right now. Please try again.');
  }

  bool _isUserVisibleTransaction(Map<dynamic, dynamic> row) {
    final type =
        row['transaction_type']?.toString() ?? row['tx_type']?.toString() ?? '';
    final direction = row['direction']?.toString() ?? '';
    final bucket = row['balance_bucket']?.toString() ?? 'available';
    if (type == 'pool_stake' && bucket == 'staked') {
      return false;
    }
    if (type == 'pool_win' && direction == 'debit' && bucket == 'pending') {
      return false;
    }
    return true;
  }

  String _transactionTypeFromRow(Map<String, dynamic> row) {
    final type =
        row['transaction_type']?.toString() ?? row['tx_type']?.toString() ?? '';
    final direction = row['direction']?.toString() ?? '';
    final bucket = row['balance_bucket']?.toString() ?? 'available';
    if (type == 'transfer' && direction == 'debit') return 'transfer_sent';
    if (type == 'transfer' && direction == 'credit') return 'transfer_received';
    if (type == 'pool_stake') return 'pool_stake';
    if (type == 'order_spend') return 'order_spend';
    if (type == 'order_earn' || type == 'welcome_credit') return type;
    if (type == 'creator_reward') return 'creator_reward';
    if (type == 'pool_refund') return 'pool_refund';
    if (type == 'pool_win') return bucket == 'pending' ? 'pending' : 'pool_win';
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
