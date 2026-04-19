import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/utils/currency_utils.dart';

void main() {
  group('FET ↔ EUR peg', () {
    test('100 FET = 1 EUR', () {
      expect(fetToEur(100), 1.0);
    });

    test('0 FET = 0 EUR', () {
      expect(fetToEur(0), 0.0);
    });

    test('50 FET = 0.5 EUR', () {
      expect(fetToEur(50), 0.5);
    });

    test('1 FET = 0.01 EUR', () {
      expect(fetToEur(1), 0.01);
    });

    test('large amounts', () {
      expect(fetToEur(100000), 1000.0);
    });
  });

  group('fetToLocal', () {
    setUp(() {
      // Reset rates
      updateLiveRates([
        {'target_currency': 'USD', 'rate': 1.08},
        {'target_currency': 'RWF', 'rate': 1450.0},
        {'target_currency': 'GBP', 'rate': 0.86},
      ]);
    });

    test('EUR returns EUR amount (no conversion)', () {
      expect(fetToLocal(100, 'EUR'), 1.0);
    });

    test('USD applies rate', () {
      expect(fetToLocal(100, 'USD'), closeTo(1.08, 0.001));
    });

    test('RWF applies rate', () {
      expect(fetToLocal(100, 'RWF'), closeTo(1450.0, 0.1));
    });

    test('unknown currency falls back to EUR', () {
      final result = fetToLocal(100, 'XYZ');
      expect(result, 1.0); // Falls back to EUR since no rate
    });

    test('case insensitive', () {
      expect(fetToLocal(100, 'usd'), closeTo(1.08, 0.001));
    });
  });

  group('formatFET', () {
    setUp(() {
      updateLiveRates([
        {'target_currency': 'USD', 'rate': 1.08},
      ]);
    });

    test('basic EUR format', () {
      final result = formatFET(100, 'EUR');
      expect(result, contains('FET'));
      expect(result, contains('100'));
      expect(result, contains('€'));
    });

    test('zero amount', () {
      final result = formatFET(0, 'EUR');
      expect(result, contains('FET'));
      expect(result, contains('0'));
    });

    test('large amount with comma formatting', () {
      final result = formatFET(150000, 'EUR');
      expect(result, contains('150,000'));
    });
  });

  group('formatFETSigned', () {
    test('positive prefix', () {
      final result = formatFETSigned(100, 'EUR', positive: true);
      expect(result, startsWith('+'));
    });

    test('negative prefix', () {
      final result = formatFETSigned(100, 'EUR', positive: false);
      expect(result, startsWith('-'));
    });
  });

  group('formatFETCompact', () {
    test('compact format', () {
      expect(formatFETCompact(500), 'FET 500');
    });

    test('large number with commas', () {
      expect(formatFETCompact(12345), 'FET 12,345');
    });
  });

  group('currencyMetadata', () {
    test('EUR metadata', () {
      final eur = currencyMetadata['EUR']!;
      expect(eur.symbol, '€');
      expect(eur.decimals, 2);
      expect(eur.spaceSeparated, false);
    });

    test('RWF metadata (zero decimals, space separated)', () {
      final rwf = currencyMetadata['RWF']!;
      expect(rwf.symbol, 'FRW');
      expect(rwf.decimals, 0);
      expect(rwf.spaceSeparated, true);
    });

    test('GBP metadata', () {
      final gbp = currencyMetadata['GBP']!;
      expect(gbp.symbol, '£');
      expect(gbp.decimals, 2);
    });
  });

  group('updateLiveRates', () {
    test('updates rates and marks hasLiveRates', () {
      updateLiveRates([
        {'target_currency': 'USD', 'rate': 1.1},
      ]);
      expect(hasLiveRates, true);
      expect(rateFor('USD'), 1.1);
    });

    test('EUR always has rate 1.0', () {
      updateLiveRates([]);
      expect(rateFor('EUR'), 1.0);
    });

    test('ignores invalid entries', () {
      updateLiveRates([
        {'target_currency': '', 'rate': 1.0},
        {'target_currency': 'USD', 'rate': -1.0},
        {'target_currency': 'GBP', 'rate': null},
        {'target_currency': null, 'rate': 0.86},
      ]);
      expect(rateFor('USD'), isNull);
      expect(rateFor('GBP'), isNull);
    });

    test('case normalizes currencies', () {
      updateLiveRates([
        {'target_currency': 'usd', 'rate': 1.1},
      ]);
      expect(rateFor('USD'), 1.1);
    });
  });

  group('countryToCurrency', () {
    test('MT maps to EUR', () {
      expect(countryToCurrency['MT'], 'EUR');
    });

    test('RW maps to RWF', () {
      expect(countryToCurrency['RW'], 'RWF');
    });

    test('GB maps to GBP', () {
      expect(countryToCurrency['GB'], 'GBP');
    });

    test('US maps to USD', () {
      expect(countryToCurrency['US'], 'USD');
    });

    test('NG maps to NGN', () {
      expect(countryToCurrency['NG'], 'NGN');
    });
  });

  group('guessUserCurrency', () {
    test('empty teams defaults to EUR', () {
      expect(guessUserCurrency([]), 'EUR');
    });

    test('local team with country code maps to currency', () {
      expect(
        guessUserCurrency([
          const FavoriteTeamEntry(
            teamId: 't1',
            countryCode: 'RW',
            source: 'local',
          ),
        ]),
        'RWF',
      );
    });

    test('popular team still uses country code', () {
      expect(
        guessUserCurrency([
          const FavoriteTeamEntry(
            teamId: 't1',
            countryCode: 'NG',
            source: 'popular',
          ),
        ]),
        'NGN',
      );
    });

    test('prefers non-big-league country codes', () {
      expect(
        guessUserCurrency([
          const FavoriteTeamEntry(teamId: 't1', countryCode: 'GB'),
          const FavoriteTeamEntry(teamId: 't2', countryCode: 'KE'),
        ]),
        'KES',
      );
    });

    test('unknown country defaults to EUR', () {
      expect(
        guessUserCurrency([
          const FavoriteTeamEntry(teamId: 't1', countryCode: 'XX'),
        ]),
        'EUR',
      );
    });
  });
}
