import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/runtime_bootstrap.dart';
import '../core/di/gateway_providers.dart';
import '../core/logging/app_logger.dart';
import '../core/utils/currency_utils.dart';
import 'auth_provider.dart';

final liveRatesProvider = FutureProvider<void>((ref) async {
  try {
    final rates = await ref.read(walletGatewayProvider).getCurrencyRates();
    if (rates.isEmpty) return;

    updateLiveRates(rates.map((rate) => rate.toJson()).toList(growable: false));
    AppLogger.d('Loaded ${rates.length} live exchange rates');
  } catch (error) {
    AppLogger.d('Failed to load live rates: $error');
  }
});

final userCurrencyProvider = FutureProvider<String>((ref) async {
  ref.watch(liveRatesProvider);
  ref.watch(authStateProvider);
  ref.watch(runtimeBootstrapProvider);

  final cache = ref.read(cacheServiceProvider);
  final cached = await cache.getString('user_currency');
  final userId = ref.read(authServiceProvider).currentUser?.id;

  if (userId == null) {
    final guestCurrency = await _guessGuestCurrency(ref, cached);
    await cache.setString('user_currency', guestCurrency);
    return guestCurrency;
  }

  try {
    await ref.read(onboardingGatewayProvider).syncCachedTeamsIfAuthenticated();

    final currencyCode = await ref
        .read(walletGatewayProvider)
        .guessUserCurrency(userId);
    if (currencyCode != null && currencyCode.isNotEmpty) {
      await cache.setString('user_currency', currencyCode);
      return currencyCode;
    }
  } catch (error) {
    AppLogger.d('Failed to infer backend currency: $error');
  }

  final fallback = await _guessGuestCurrency(ref, cached);
  await cache.setString('user_currency', fallback);
  return fallback;
});

final fetDisplayProvider = Provider.family<String, int>((ref, amount) {
  final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
  return formatFET(amount, currency);
});

final fetDisplaySignedProvider =
    Provider.family<String, ({int amount, bool positive})>((ref, params) {
      final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
      return formatFETSigned(
        params.amount,
        currency,
        positive: params.positive,
      );
    });

final userFanIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(authStateProvider);

  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return null;

  try {
    return ref.read(walletGatewayProvider).getFanId(userId);
  } catch (error) {
    AppLogger.d('Failed to load fan id: $error');
    return null;
  }
});

Future<String> _guessGuestCurrency(Ref ref, String? cached) async {
  final cachedTeams = await ref
      .read(onboardingGatewayProvider)
      .getCachedFavoriteTeams();
  if (cachedTeams.isEmpty) return cached ?? 'EUR';

  final entries = cachedTeams
      .map(
        (team) => FavoriteTeamEntry(
          teamId: team.teamId,
          countryCode: team.teamCountryCode,
          source: team.source.contains('local') ? 'local' : team.source,
        ),
      )
      .toList(growable: false);

  return guessUserCurrency(entries);
}
