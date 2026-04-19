import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabaseInitialized;

/// FET exchange rate model.
class FetExchangeRate {
  const FetExchangeRate({
    required this.currency,
    required this.symbol,
    required this.rate,
  });

  final String currency;
  final String symbol;
  final double rate;

  factory FetExchangeRate.fromJson(Map<String, dynamic> json) {
    return FetExchangeRate(
      currency: json['currency'] as String? ?? 'EUR',
      symbol: json['symbol'] as String? ?? '€',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.01,
    );
  }
}

/// Default exchange rates — used when Supabase table doesn't exist or fails.
const _defaultRates = [
  FetExchangeRate(currency: 'EUR', symbol: '€', rate: 0.01),
  FetExchangeRate(currency: 'USD', symbol: '\$', rate: 0.011),
  FetExchangeRate(currency: 'RWF', symbol: 'FRw', rate: 14.50),
];

/// Provider that fetches exchange rates from Supabase `fet_exchange_rates` table.
/// Falls back to hardcoded defaults if the table doesn't exist or query fails.
final fetExchangeRatesProvider =
    FutureProvider.autoDispose<List<FetExchangeRate>>((ref) async {
  if (!supabaseInitialized) return _defaultRates;

  try {
    final response = await Supabase.instance.client
        .from('fet_exchange_rates')
        .select('currency, symbol, rate')
        .eq('active', true)
        .order('currency');

    if (response.isEmpty) return _defaultRates;

    return (response as List<dynamic>)
        .map(
          (row) => FetExchangeRate.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  } catch (_) {
    // Table may not exist yet — gracefully fall back to defaults
    return _defaultRates;
  }
});

/// Minimum FET payout threshold.
const int fetMinimumPayout = 500;
