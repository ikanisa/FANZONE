import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';

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

final fetExchangeRatesProvider =
    FutureProvider.autoDispose<List<FetExchangeRate>>((ref) async {
      try {
        final response = await ref
            .read(walletGatewayProvider)
            .getFetExchangeRates();
        if (response.isEmpty) return const <FetExchangeRate>[];

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
        return const <FetExchangeRate>[];
      }
    });

const int fetMinimumPayout = 500;
