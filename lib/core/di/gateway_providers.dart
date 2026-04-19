/// Riverpod providers for ALL gateways & core services.
///
/// Phase 2 DI migration: replaces `getIt<T>()` with `ref.read(tProvider)`.
/// Each provider mirrors one lazySingleton from injection.config.dart.
library;

import 'dart:ui' show PlatformDispatcher;

import '../config/bootstrap_config.dart';
import '../config/runtime_bootstrap.dart';
import '../utils/currency_utils.dart' as currency_utils;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/team_search_database.dart' as team_db;
// ── Core layer ─────────────────────────────────────────────
import '../cache/cache_service.dart';
import '../cache/shared_preferences_cache_service.dart';
import '../logging/app_logger.dart';
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

BootstrapConfigService? _bootstrapRuntimeService;
SupabaseConnection? _bootstrapRuntimeConnection;

String _bootstrapMarketKey() {
  final countryCode = PlatformDispatcher.instance.locale.countryCode;
  final normalized = countryCode?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return 'global';
  return normalized;
}

String _bootstrapPlatformKey() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return 'all';
  }
}

String _regionForTeamRow(Map<String, dynamic> row, BootstrapConfig config) {
  final countryCode = row['country_code']?.toString();
  final regionFromCode = config.regionForCountryCode(countryCode);
  if (regionFromCode != 'global') return regionFromCode;

  final countryName = row['country']?.toString();
  if (countryName != null && countryName.isNotEmpty) {
    for (final info in config.regions.values) {
      if (info.countryName.toLowerCase() == countryName.toLowerCase()) {
        return info.region;
      }
    }
  }

  return 'global';
}

Future<TeamSearchCatalog?> _loadRemoteTeamSearchCatalog(
  SupabaseConnection connection,
  BootstrapConfig config,
) async {
  final client = connection.client;
  if (client == null) return null;

  final rows = await client
      .from('teams')
      .select(
        'id, name, short_name, country, country_code, league_name, crest_url, '
        'search_terms, is_popular_pick, is_featured, is_active, '
        'popular_pick_rank',
      )
      .eq('is_active', true)
      .order('is_popular_pick', ascending: false)
      .order('popular_pick_rank', ascending: true)
      .order('name');

  final teams = (rows as List)
      .whereType<Map>()
      .map(Map<String, dynamic>.from)
      .map((row) {
        final searchTerms = (row['search_terms'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList(growable: false);

        return OnboardingTeam.fromJson({
          'id': row['id'],
          'name': row['name'],
          'country': row['country'],
          'league': row['league_name'],
          'aliases': searchTerms,
          'region': _regionForTeamRow(row, config),
          'is_popular':
              row['is_popular_pick'] == true || row['is_featured'] == true,
          'short_name': row['short_name'],
          'crest_url': row['crest_url'],
          'country_code': row['country_code'],
        });
      })
      .toList(growable: false);

  if (teams.isEmpty) return null;
  return TeamSearchCatalog(teams);
}

void _applyRuntimeBootstrap(BootstrapConfig config) {
  runtimeBootstrapStore.update(config);
  currency_utils.hydrateCurrencyDisplay(config.currencyDisplay);
}

Future<void> refreshRuntimeBootstrapData({
  String market = 'global',
  String platform = 'all',
}) async {
  final service = _bootstrapRuntimeService;
  if (service == null) return;

  final config = await service.refresh(
    market: market == 'global' ? _bootstrapMarketKey() : market,
    platform: platform == 'all' ? _bootstrapPlatformKey() : platform,
  );
  _applyRuntimeBootstrap(config);

  final connection = _bootstrapRuntimeConnection;
  if (connection == null) return;

  try {
    final remoteCatalog = await _loadRemoteTeamSearchCatalog(
      connection,
      config,
    );
    if (remoteCatalog != null) {
      team_db.initTeamSearchDatabase(catalog: remoteCatalog);
    }
  } catch (_) {
    // Keep the asset-backed catalog when the live data plane is unavailable.
  }
}

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

final marketPreferencesGatewayProvider = Provider<MarketPreferencesGateway>((
  ref,
) {
  return SupabaseMarketPreferencesGateway(
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseConnectionProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// HOME / CATALOG
// ═══════════════════════════════════════════════════════════

final competitionCatalogGatewayProvider = Provider<CompetitionCatalogGateway>((
  ref,
) {
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
  return SupabaseSearchCatalogGateway(ref.watch(supabaseConnectionProvider));
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

final seasonLeaderboardGatewayProvider = Provider<SeasonLeaderboardGateway>((
  ref,
) {
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

// ═══════════════════════════════════════════════════════════
// BOOTSTRAP CONFIG (replaces all hardcoded constants)
// ═══════════════════════════════════════════════════════════

final bootstrapConfigServiceProvider =
    ChangeNotifierProvider<BootstrapConfigService>((ref) {
      return BootstrapConfigService(
        ref.watch(cacheServiceProvider),
        ref.watch(supabaseConnectionProvider),
      );
    });

/// Preloaded bootstrap config — available synchronously after startup.
final bootstrapConfigProvider = Provider<BootstrapConfig>((ref) {
  return ref.watch(bootstrapConfigServiceProvider).config;
});

/// Call this during app startup to resolve async singletons,
/// then pass the results as ProviderScope overrides.
Future<List<Override>> resolveAsyncOverrides() async {
  final prefs = await SharedPreferences.getInstance();

  // Initialize global singletons for static services outside Riverpod scope
  SharedPreferencesCacheService.initGlobal(prefs);

  // Load bootstrap config from Supabase (with cache fallback)
  final cacheService = SharedPreferencesCacheService(prefs);
  final connection = SupabaseConnectionImpl();
  final bootstrapService = BootstrapConfigService(cacheService, connection);
  final config = await bootstrapService.load(
    market: _bootstrapMarketKey(),
    platform: _bootstrapPlatformKey(),
  );
  _bootstrapRuntimeService = bootstrapService;
  _bootstrapRuntimeConnection = connection;

  _applyRuntimeBootstrap(config);

  // ── Team Catalog: DB-first, JSON-fallback ──
  // Try the teams table directly (the single source of truth).
  // Fall back to the bundled JSON asset only when the DB is unreachable
  // or the teams table is empty (e.g., first deploy before data sync).
  TeamSearchCatalog? catalog;
  try {
    catalog = await _loadRemoteTeamSearchCatalog(connection, config);
  } catch (e) {
    AppLogger.d(
      'Startup: DB team catalog load failed, falling back to JSON: $e',
    );
  }
  if (catalog == null || catalog.allTeams.isEmpty) {
    final raw = await rootBundle.loadString(
      'assets/data/team_search_database.json',
    );
    catalog = TeamSearchCatalog.fromRawJson(raw);
  }
  team_db.initTeamSearchDatabase(catalog: catalog);

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    teamSearchCatalogProvider.overrideWithValue(catalog),
    bootstrapConfigServiceProvider.overrideWith((ref) => bootstrapService),
  ];
}
