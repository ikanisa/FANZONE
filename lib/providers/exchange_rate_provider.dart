import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../features/wallet/data/wallet_gateway.dart';

class FetExchangeRate {
  const FetExchangeRate({
    required this.currency,
    required this.symbol,
    required this.rate,
  });

  final String currency;
  final String symbol;
  final double rate;
}

const _defaultRates = [
  FetExchangeRate(currency: 'EUR', symbol: '€', rate: 0.01),
  FetExchangeRate(currency: 'USD', symbol: '\$', rate: 0.011),
  FetExchangeRate(currency: 'RWF', symbol: 'FRw', rate: 14.50),
];

final fetExchangeRatesProvider =
    FutureProvider.autoDispose<List<FetExchangeRate>>((ref) async {
      try {
        final response = await getIt<WalletGateway>().getFetExchangeRates();
        if (response.isEmpty) return _defaultRates;

        return response
            .map(
              (row) => FetExchangeRate(
                currency: row.currency,
                symbol: row.symbol,
                rate: row.rate,
              ),
            )
            .toList(growable: false);
      } catch (_) {
        return _defaultRates;
      }
    });

const int fetMinimumPayout = 500;
