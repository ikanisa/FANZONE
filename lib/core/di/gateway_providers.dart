/// Riverpod providers for ALL gateways & core services.
///
/// Phase 2 DI migration: replaces `getIt<T>()` with `ref.read(tProvider)`.
/// Each provider mirrors one lazySingleton from injection.config.dart.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/team_search_database.dart' as team_db;
// ── Core layer ─────────────────────────────────────────────
import '../cache/cache_service.dart';
import '../cache/shared_preferences_cache_service.dart';
import '../supabase/supabase_connection.dart';

// ── Feature gateways ───────────────────────────────────────
import '../../features/auth/data/auth_gateway.dart';
import '../../features/community/data/community_gateway.dart';
import '../../features/home/data/catalog_gateway.dart';
import '../../features/home/data/match_detail_gateway.dart';
import '../../features/home/data/match_listing_gateway.dart';
import '../../features/home/data/matches_gateway.dart';
import '../../features/onboarding/data/onboarding_gateway.dart';
import '../../features/onboarding/data/team_search_catalog.dart';
import '../../features/predict/data/predict_gateway.dart';
import '../../features/profile/data/contest_gateway.dart';
import '../../features/profile/data/engagement_gateway.dart';
import '../../features/profile/data/fan_profile_gateway.dart';
import '../../features/profile/data/season_leaderboard_gateway.dart';
import '../../features/settings/data/account_settings_gateway.dart';
import '../../features/settings/data/competition_preferences_gateway.dart';
import '../../features/settings/data/market_preferences_gateway.dart';
import '../../features/settings/data/notification_settings_gateway.dart';
import '../../features/wallet/data/wallet_gateway.dart';

// ═══════════════════════════════════════════════════════════
// CORE SINGLETONS
// ═══════════════════════════════════════════════════════════

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at app startup via ProviderScope.',
  );
});

final teamSearchCatalogProvider = Provider<TeamSearchCatalog>((ref) {
  throw UnimplementedError(
    'teamSearchCatalogProvider must be overridden at app startup via ProviderScope.',
  );
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return SharedPreferencesCacheService(ref.watch(sharedPreferencesProvider));
});

final supabaseConnectionProvider = Provider<SupabaseConnection>((ref) {
  return SupabaseConnectionImpl();
});

// ═══════════════════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════════════════

final authGatewayProvider = Provider<AuthGateway>((ref) {
  return SupabaseAuthGateway(ref.watch(supabaseConnectionProvider));
});

// ═══════════════════════════════════════════════════════════
// SETTINGS
// ═══════════════════════════════════════════════════════════

final competitionPreferencesGatewayProvider =
    Provider<CompetitionPreferencesGateway>((ref) {
  return SupabaseCompetitionPreferencesGateway(
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

final accountSettingsGatewayProvider = Provider<AccountSettingsGateway>((ref) {
  return SupabaseAccountSettingsGateway(
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

final notificationSettingsGatewayProvider =
    Provider<NotificationSettingsGateway>((ref) {
  return SupabaseNotificationSettingsGateway(
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

final marketPreferencesGatewayProvider =
    Provider<MarketPreferencesGateway>((ref) {
  return SupabaseMarketPreferencesGateway(
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// HOME / CATALOG
// ═══════════════════════════════════════════════════════════

final competitionCatalogGatewayProvider =
    Provider<CompetitionCatalogGateway>((ref) {
  return SupabaseCompetitionCatalogGateway(
    ref.watch(supabaseConnectionProvider),
  );
});

final teamCatalogGatewayProvider = Provider<TeamCatalogGateway>((ref) {
  return SupabaseTeamCatalogGateway(ref.watch(supabaseConnectionProvider));
});

final eventCatalogGatewayProvider = Provider<EventCatalogGateway>((ref) {
  return SupabaseEventCatalogGateway(ref.watch(supabaseConnectionProvider));
});

final searchCatalogGatewayProvider = Provider<SearchCatalogGateway>((ref) {
  return SupabaseSearchCatalogGateway(
    ref.watch(supabaseConnectionProvider),
  );
});

final catalogGatewayProvider = Provider<CatalogGateway>((ref) {
  return SupabaseCatalogGateway(
    ref.watch(competitionCatalogGatewayProvider),
    ref.watch(teamCatalogGatewayProvider),
    ref.watch(eventCatalogGatewayProvider),
    ref.watch(searchCatalogGatewayProvider),
  );
});

final matchListingGatewayProvider = Provider<MatchListingGateway>((ref) {
  return SupabaseMatchListingGateway(ref.watch(supabaseConnectionProvider));
});

final matchDetailGatewayProvider = Provider<MatchDetailGateway>((ref) {
  return SupabaseMatchDetailGateway(ref.watch(supabaseConnectionProvider));
});

final matchesGatewayProvider = Provider<MatchesGateway>((ref) {
  return SupabaseMatchesGateway(
    ref.watch(matchListingGatewayProvider),
    ref.watch(matchDetailGatewayProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// ONBOARDING
// ═══════════════════════════════════════════════════════════

final onboardingGatewayProvider = Provider<OnboardingGateway>((ref) {
  return SupabaseOnboardingGateway(
    ref.watch(teamSearchCatalogProvider),
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// PREDICT
// ═══════════════════════════════════════════════════════════

final predictionPoolGatewayProvider = Provider<PredictionPoolGateway>((ref) {
  return SupabasePredictionPoolGateway(ref.watch(supabaseConnectionProvider));
});

final leaderboardGatewayProvider = Provider<LeaderboardGateway>((ref) {
  return SupabaseLeaderboardGateway(ref.watch(supabaseConnectionProvider));
});

final dailyChallengeGatewayProvider = Provider<DailyChallengeGateway>((ref) {
  return SupabaseDailyChallengeGateway(ref.watch(supabaseConnectionProvider));
});

final predictionSlipGatewayProvider = Provider<PredictionSlipGateway>((ref) {
  return SupabasePredictionSlipGateway(ref.watch(supabaseConnectionProvider));
});

final predictGatewayProvider = Provider<PredictGateway>((ref) {
  return SupabasePredictGateway(
    ref.watch(predictionPoolGatewayProvider),
    ref.watch(leaderboardGatewayProvider),
    ref.watch(dailyChallengeGatewayProvider),
    ref.watch(predictionSlipGatewayProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// PROFILE
// ═══════════════════════════════════════════════════════════

final contestGatewayProvider = Provider<ContestGateway>((ref) {
  return SupabaseContestGateway(ref.watch(supabaseConnectionProvider));
});

final seasonLeaderboardGatewayProvider =
    Provider<SeasonLeaderboardGateway>((ref) {
  return SupabaseSeasonLeaderboardGateway(
    ref.watch(supabaseConnectionProvider),
  );
});

final fanProfileGatewayProvider = Provider<FanProfileGateway>((ref) {
  return SupabaseFanProfileGateway(ref.watch(supabaseConnectionProvider));
});

final engagementGatewayProvider = Provider<EngagementGateway>((ref) {
  return SupabaseEngagementGateway(
    ref.watch(contestGatewayProvider),
    ref.watch(seasonLeaderboardGatewayProvider),
    ref.watch(fanProfileGatewayProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// COMMUNITY
// ═══════════════════════════════════════════════════════════

final teamSupportGatewayProvider = Provider<TeamSupportGateway>((ref) {
  return SupabaseTeamSupportGateway(
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

final teamNewsGatewayProvider = Provider<TeamNewsGateway>((ref) {
  return SupabaseTeamNewsGateway(ref.watch(supabaseConnectionProvider));
});

final feedGatewayProvider = Provider<FeedGateway>((ref) {
  return SupabaseFeedGateway(
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

final communityGatewayProvider = Provider<CommunityGateway>((ref) {
  return SupabaseCommunityGateway(
    ref.watch(teamSupportGatewayProvider),
    ref.watch(teamNewsGatewayProvider),
    ref.watch(feedGatewayProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// WALLET
// ═══════════════════════════════════════════════════════════

final walletGatewayProvider = Provider<WalletGateway>((ref) {
  return SupabaseWalletGateway(ref.watch(supabaseConnectionProvider));
});

/// Call this during app startup to resolve async singletons,
/// then pass the results as ProviderScope overrides.
Future<List<Override>> resolveAsyncOverrides() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = await rootBundle.loadString('assets/data/team_search_database.json');
  final catalog = TeamSearchCatalog.fromRawJson(raw);

  // Initialize global singletons for static services outside Riverpod scope
  SharedPreferencesCacheService.initGlobal(prefs);
  team_db.initTeamSearchDatabase(catalog: catalog);

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    teamSearchCatalogProvider.overrideWithValue(catalog),
  ];
}
