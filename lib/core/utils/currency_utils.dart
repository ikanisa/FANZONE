/// FET currency utility — backend-fed exchange rates and local formatting.
///
/// Base peg: 100 FET = 1 EUR (hardcoded, never changes).
/// Numeric exchange rates are sourced from the backend `currency_rates` table.
/// Currency display metadata (symbol, decimals, space-separated) is now
/// loaded from the `currency_display_metadata` Supabase table via
/// [BootstrapConfig].  The hardcoded fallback is used only on first cold start.
library;

import 'package:intl/intl.dart';

import '../config/bootstrap_config.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final int decimals;
  final bool spaceSeparated;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    this.decimals = 2,
    this.spaceSeparated = false,
  });
}

/// Offline fallback — used only when bootstrap config is empty.
const Map<String, CurrencyInfo> _defaultCurrencyMetadata = {
  'EUR': CurrencyInfo(code: 'EUR', symbol: '€'),
  'GBP': CurrencyInfo(code: 'GBP', symbol: '£'),
  'USD': CurrencyInfo(code: 'USD', symbol: '\$'),
  'CAD': CurrencyInfo(code: 'CAD', symbol: 'C\$'),
  'CHF': CurrencyInfo(code: 'CHF', symbol: 'CHF', spaceSeparated: true),
  'SEK': CurrencyInfo(code: 'SEK', symbol: 'kr', spaceSeparated: true),
  'NOK': CurrencyInfo(code: 'NOK', symbol: 'kr', spaceSeparated: true),
  'DKK': CurrencyInfo(code: 'DKK', symbol: 'kr', spaceSeparated: true),
  'PLN': CurrencyInfo(code: 'PLN', symbol: 'zł', spaceSeparated: true),
  'TRY': CurrencyInfo(code: 'TRY', symbol: '₺'),
  'BRL': CurrencyInfo(code: 'BRL', symbol: 'R\$'),
  'MXN': CurrencyInfo(code: 'MXN', symbol: 'MX\$', decimals: 0, spaceSeparated: true),
  'ARS': CurrencyInfo(code: 'ARS', symbol: 'ARS', decimals: 0, spaceSeparated: true),
  'RWF': CurrencyInfo(code: 'RWF', symbol: 'FRW', decimals: 0, spaceSeparated: true),
  'NGN': CurrencyInfo(code: 'NGN', symbol: '₦', decimals: 0),
  'KES': CurrencyInfo(code: 'KES', symbol: 'KSh', decimals: 0, spaceSeparated: true),
  'ZAR': CurrencyInfo(code: 'ZAR', symbol: 'R'),
  'EGP': CurrencyInfo(code: 'EGP', symbol: 'E£', decimals: 0),
  'TZS': CurrencyInfo(code: 'TZS', symbol: 'TSh', decimals: 0, spaceSeparated: true),
  'UGX': CurrencyInfo(code: 'UGX', symbol: 'USh', decimals: 0, spaceSeparated: true),
  'GHS': CurrencyInfo(code: 'GHS', symbol: 'GH₵'),
  'XOF': CurrencyInfo(code: 'XOF', symbol: 'CFA', decimals: 0, spaceSeparated: true),
  'TND': CurrencyInfo(code: 'TND', symbol: 'DT', spaceSeparated: true),
  'DZD': CurrencyInfo(code: 'DZD', symbol: 'DA', decimals: 0, spaceSeparated: true),
  'MAD': CurrencyInfo(code: 'MAD', symbol: 'MAD', spaceSeparated: true),
  'CDF': CurrencyInfo(code: 'CDF', symbol: 'FC', decimals: 0, spaceSeparated: true),
  'ETB': CurrencyInfo(code: 'ETB', symbol: 'Br', decimals: 0, spaceSeparated: true),
  'INR': CurrencyInfo(code: 'INR', symbol: '₹', decimals: 0),
  'JPY': CurrencyInfo(code: 'JPY', symbol: '¥', decimals: 0),
  'CNY': CurrencyInfo(code: 'CNY', symbol: '¥'),
  'AED': CurrencyInfo(code: 'AED', symbol: 'AED', spaceSeparated: true),
  'SAR': CurrencyInfo(code: 'SAR', symbol: 'SAR', spaceSeparated: true),
  'AUD': CurrencyInfo(code: 'AUD', symbol: 'A\$'),
  'NZD': CurrencyInfo(code: 'NZD', symbol: 'NZ\$'),
};

/// Live currency display metadata — hydrated from [BootstrapConfig].
Map<String, CurrencyInfo> _liveCurrencyMetadata = {};

/// Hydrate currency display metadata from BootstrapConfig (DB-driven).
///
/// Call this once after BootstrapConfig loads at startup.
void hydrateCurrencyDisplay(Map<String, CurrencyDisplayInfo> dbData) {
  if (dbData.isEmpty) return;
  final next = <String, CurrencyInfo>{};
  for (final entry in dbData.entries) {
    next[entry.key] = CurrencyInfo(
      code: entry.key,
      symbol: entry.value.symbol,
      decimals: entry.value.decimals,
      spaceSeparated: entry.value.spaceSeparated,
    );
  }
  _liveCurrencyMetadata = next;
}

/// Returns currency metadata: DB-driven if available, else hardcoded fallback.
Map<String, CurrencyInfo> get currencies =>
    _liveCurrencyMetadata.isNotEmpty ? _liveCurrencyMetadata : _defaultCurrencyMetadata;

/// DEPRECATED — use [currencies] getter instead.
Map<String, CurrencyInfo> get currencyMetadata => currencies;

Map<String, double> _liveRates = {'EUR': 1.0};

void updateLiveRates(List<Map<String, dynamic>> rows) {
  final next = <String, double>{'EUR': 1.0};

  for (final row in rows) {
    final code = row['target_currency']?.toString().trim().toUpperCase();
    final rate = (row['rate'] as num?)?.toDouble();
    if (code == null || code.isEmpty || rate == null || rate <= 0) continue;
    next[code] = rate;
  }

  _liveRates = next;
}

bool get hasLiveRates => _liveRates.length > 1;

double? rateFor(String currencyCode) {
  final normalized = currencyCode.trim().toUpperCase();
  return _liveRates[normalized];
}

const Map<String, String> countryToCurrency = {
  'MT': 'EUR',
  'ES': 'EUR',
  'DE': 'EUR',
  'FR': 'EUR',
  'IT': 'EUR',
  'NL': 'EUR',
  'PT': 'EUR',
  'AT': 'EUR',
  'BE': 'EUR',
  'FI': 'EUR',
  'IE': 'EUR',
  'GR': 'EUR',
  'GB': 'GBP',
  'CH': 'CHF',
  'SE': 'SEK',
  'NO': 'NOK',
  'DK': 'DKK',
  'PL': 'PLN',
  'TR': 'TRY',
  'US': 'USD',
  'CA': 'CAD',
  'BR': 'BRL',
  'MX': 'MXN',
  'AR': 'ARS',
  'RW': 'RWF',
  'NG': 'NGN',
  'KE': 'KES',
  'ZA': 'ZAR',
  'EG': 'EGP',
  'TZ': 'TZS',
  'UG': 'UGX',
  'GH': 'GHS',
  'TN': 'TND',
  'DZ': 'DZD',
  'MA': 'MAD',
  'CD': 'CDF',
  'ET': 'ETB',
  'SN': 'XOF',
  'CI': 'XOF',
  'ML': 'XOF',
  'BF': 'XOF',
  'NE': 'XOF',
  'TG': 'XOF',
  'BJ': 'XOF',
  'GW': 'XOF',
  'IN': 'INR',
  'JP': 'JPY',
  'CN': 'CNY',
  'AE': 'AED',
  'SA': 'SAR',
  'AU': 'AUD',
  'NZ': 'NZD',
};

class FavoriteTeamEntry {
  final String teamId;
  final String? countryCode;
  final String source;

  const FavoriteTeamEntry({
    required this.teamId,
    this.countryCode,
    this.source = 'popular',
  });
}

String guessUserCurrency(List<FavoriteTeamEntry> teams) {
  if (teams.isEmpty) return 'EUR';

  final localTeam = teams.where((team) => team.source == 'local').firstOrNull;
  if (localTeam?.countryCode != null) {
    final mapped = countryToCurrency[localTeam!.countryCode!.toUpperCase()];
    if (mapped != null) return mapped;
  }

  const bigLeagueCountries = {'GB', 'ES', 'DE', 'FR', 'IT', 'NL', 'PT'};
  final localSignal = teams.where((team) {
    final code = team.countryCode?.toUpperCase();
    return code != null && !bigLeagueCountries.contains(code);
  }).firstOrNull;
  if (localSignal?.countryCode != null) {
    final mapped = countryToCurrency[localSignal!.countryCode!.toUpperCase()];
    if (mapped != null) return mapped;
  }

  for (final team in teams) {
    final code = team.countryCode?.toUpperCase();
    if (code == null) continue;
    final mapped = countryToCurrency[code];
    if (mapped != null) return mapped;
  }

  return 'EUR';
}

double fetToEur(int fetAmount) => fetAmount / 100.0;

double fetToLocal(int fetAmount, String currencyCode) {
  final normalized = currencyCode.trim().toUpperCase();
  final eurAmount = fetToEur(fetAmount);
  final rate = rateFor(normalized);
  if (normalized == 'EUR' || rate == null) return eurAmount;
  return eurAmount * rate;
}

String formatFET(int fetAmount, String currencyCode) {
  final eurAmount = fetToEur(fetAmount);
  final normalized = currencyCode.trim().toUpperCase();
  final preferredInfo = currencies[normalized];
  final canUsePreferred = normalized == 'EUR' || rateFor(normalized) != null;
  final info = canUsePreferred
      ? (preferredInfo ?? const CurrencyInfo(code: 'EUR', symbol: '€'))
      : const CurrencyInfo(code: 'EUR', symbol: '€');
  final localAmount = canUsePreferred
      ? fetToLocal(fetAmount, normalized)
      : eurAmount;

  return 'FET ${_formatNumber(fetAmount)} (${_formatCurrency(localAmount, info)})';
}

String formatFETSigned(
  int fetAmount,
  String currencyCode, {
  required bool positive,
}) {
  final prefix = positive ? '+' : '-';
  return '$prefix ${formatFET(fetAmount, currencyCode)}';
}

String formatFETCompact(int fetAmount) {
  return 'FET ${_formatNumber(fetAmount)}';
}

String _formatCurrency(double amount, CurrencyInfo info) {
  if (info.decimals == 0) {
    final rounded = _formatNumber(amount.round());
    return info.spaceSeparated
        ? '${info.symbol} $rounded'
        : '${info.symbol}$rounded';
  }

  final isWhole = amount == amount.roundToDouble();
  final formatter = NumberFormat.currency(
    symbol: info.spaceSeparated ? '${info.symbol} ' : info.symbol,
    decimalDigits: isWhole ? 0 : info.decimals,
  );
  return formatter.format(amount);
}

String _formatNumber(int value) {
  return NumberFormat('#,###').format(value);
}
