import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../core/market/launch_market.dart';

/// User region derived from explicit market preferences first, then teams.
///
/// Region only affects content priority and ordering. It never locks content.
enum UserRegion { africa, europe, northAmerica, global }

/// Provider that resolves the user's region from market preferences or teams.
final userRegionProvider = FutureProvider<UserRegion>((ref) async {
  final marketPreferences = await ref
      .read(marketPreferencesGatewayProvider)
      .getUserMarketPreferences();
  final preferredRegion = normalizeRegionKey(marketPreferences.primaryRegion);

  if (preferredRegion == 'africa') return UserRegion.africa;
  if (preferredRegion == 'europe') return UserRegion.europe;
  if (preferredRegion == 'north_america') return UserRegion.northAmerica;

  final cached = await ref
      .read(onboardingGatewayProvider)
      .getCachedFavoriteTeams();
  if (cached.isEmpty) return UserRegion.global;

  // Priority: local team > first team with a country code
  final localTeam = cached.where((row) => row.source == 'local').firstOrNull;
  final primaryTeam = localTeam ?? cached.firstOrNull;
  final countryCode = primaryTeam?.teamCountryCode?.toUpperCase();

  if (countryCode == null || countryCode.isEmpty) return UserRegion.global;

  return regionFromCountryCode(ref, countryCode);
});

/// Cached canonical region string for UI and query composition.
final userRegionStringProvider = Provider<String>((ref) {
  final region = ref.watch(userRegionProvider).valueOrNull ?? UserRegion.global;
  switch (region) {
    case UserRegion.africa:
      return 'africa';
    case UserRegion.europe:
      return 'europe';
    case UserRegion.northAmerica:
      return 'north_america';
    case UserRegion.global:
      return 'global';
  }
});

/// Region variants to use for backward-compatible Supabase filters.
final userRegionQueryValuesProvider = Provider<List<String>>((ref) {
  final region = ref.watch(userRegionStringProvider);
  return queryRegionVariants(region);
});

/// Map a 2-letter country code to a UserRegion — using DB-driven bootstrap config.
UserRegion regionFromCountryCode(Ref ref, String code) {
  final bootstrapConfig = ref.read(bootstrapConfigProvider);
  final region = bootstrapConfig.regionForCountryCode(code);

  switch (region) {
    case 'africa':
      return UserRegion.africa;
    case 'north_america':
      return UserRegion.northAmerica;
    case 'europe':
      return UserRegion.europe;
    default:
      return UserRegion.global;
  }
}
