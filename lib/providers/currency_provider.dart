import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../core/utils/currency_utils.dart';
import '../features/onboarding/providers/onboarding_service.dart';
import '../main.dart' show supabaseInitialized;
import 'auth_provider.dart';

final liveRatesProvider = FutureProvider<void>((ref) async {
  if (!supabaseInitialized) return;

  try {
    final client = Supabase.instance.client;
    final data = await client
        .from('currency_rates')
        .select('base_currency, target_currency, rate, source, updated_at')
        .eq('base_currency', 'EUR')
        .order('target_currency');

    updateLiveRates(List<Map<String, dynamic>>.from(data as List));
    AppLogger.d('Loaded ${(data as List).length} live exchange rates');
  } catch (error) {
    AppLogger.d('Failed to load live rates: $error');
  }
});

final userCurrencyProvider = FutureProvider<String>((ref) async {
  ref.watch(liveRatesProvider);
  ref.watch(authStateProvider);

  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString('user_currency');

  if (!supabaseInitialized) {
    return cached ?? await _guessGuestCurrency(prefs);
  }

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  if (userId == null) {
    final guestCurrency = await _guessGuestCurrency(prefs);
    await prefs.setString('user_currency', guestCurrency);
    return guestCurrency;
  }

  try {
    await OnboardingService.syncCachedTeamsIfAuthenticated();

    final response = await client.rpc(
      'guess_user_currency',
      params: {'p_user_id': userId},
    );

    final currencyCode = (response as Map<String, dynamic>)['currency_code']
        ?.toString()
        .trim()
        .toUpperCase();

    if (currencyCode != null && currencyCode.isNotEmpty) {
      await prefs.setString('user_currency', currencyCode);
      return currencyCode;
    }
  } catch (error) {
    AppLogger.d('Failed to infer backend currency: $error');
  }

  final fallback = cached ?? await _guessGuestCurrency(prefs);
  await prefs.setString('user_currency', fallback);
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

  if (!supabaseInitialized) return null;

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final data = await client
        .from('profiles')
        .select('fan_id')
        .eq('id', userId)
        .maybeSingle();

    if (data != null) {
      return data['fan_id']?.toString();
    }

    final fallback = await client
        .from('profiles')
        .select('fan_id')
        .eq('user_id', userId)
        .maybeSingle();

    return fallback?['fan_id']?.toString();
  } catch (error) {
    AppLogger.d('Failed to load fan id: $error');
    return null;
  }
});

Future<String> _guessGuestCurrency(SharedPreferences prefs) async {
  final cachedTeams = await OnboardingService.getCachedFavoriteTeams();
  if (cachedTeams.isEmpty) return prefs.getString('user_currency') ?? 'EUR';

  final entries = cachedTeams.map((row) {
    return FavoriteTeamEntry(
      teamId: row['team_id']?.toString() ?? '',
      countryCode: row['team_country_code']?.toString(),
      source: row['source']?.toString() ?? 'popular',
    );
  }).toList();

  return guessUserCurrency(entries);
}
