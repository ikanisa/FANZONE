import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/wallet.dart';

abstract interface class WalletGateway {
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
  final Map<String, List<WalletTransaction>> _localTransactions =
      <String, List<WalletTransaction>>{};

  @override
  Future<int> getAvailableBalance(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return _cachedBalanceOrThrow(userId);
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

    return _cachedBalanceOrThrow(userId);
  }

  @override
  Future<void> transferByFanId(WalletTransferByFanIdDto request) async {
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('FET transfer');
    }

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

  int _cachedBalanceOrThrow(String userId) {
    if (_localBalances.containsKey(userId)) {
      return _cachedBalance(userId);
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
