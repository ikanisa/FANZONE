/// Riverpod providers for ALL gateways & core services.
///
/// Phase 2 DI migration: replaces `getIt<T>()` with `ref.read(tProvider)`.
/// Each provider mirrors one lazySingleton from injection.config.dart.
library;

import 'dart:ui' show PlatformDispatcher;

import '../config/bootstrap_config.dart';
import '../config/runtime_bootstrap.dart';
import '../../config/app_config.dart';
import '../utils/currency_utils.dart' as currency_utils;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

const _teamCatalogSelectColumns =
    'id, name, short_name, country, country_code, league_name, region, '
    'logo_url, crest_url, aliases, search_terms, is_popular_pick, '
    'is_featured, is_active, popular_pick_rank';
const _teamCatalogLegacySelectColumns =
    'id, name, short_name, country, country_code, league_name, region, '
    'crest_url, search_terms, is_popular_pick, is_featured, is_active, '
    'popular_pick_rank';

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
  final explicitRegion = row['region']?.toString().trim().toLowerCase();
  if (explicitRegion != null && explicitRegion.isNotEmpty) {
    return explicitRegion;
  }

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

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  return const <String>[];
}

String? _firstString(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

int? _firstInt(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

OnboardingTeam? _mapTeamRow(Map<String, dynamic> row, BootstrapConfig config) {
  final id = _firstString(row, const ['team_id', 'id']);
  final name = _firstString(row, const ['team_name', 'name']);
  if (id == null || name == null) return null;

  final countryCode = _firstString(row, const [
    'team_country_code',
    'country_code',
  ]);
  final country =
      _firstString(row, const ['team_country', 'country']) ??
      config.countryNameForCode(countryCode) ??
      '';
  final league = _firstString(row, const [
    'team_league',
    'league_name',
    'league',
  ]);
  final aliases = <String>{
    ..._stringList(row['aliases']),
    ..._stringList(row['search_terms']),
  }.toList(growable: false);

  return OnboardingTeam.fromJson({
    'id': id,
    'name': name,
    'country': country,
    'league': league,
    'aliases': aliases,
    'region':
        _firstString(row, const ['region']) ?? _regionForTeamRow(row, config),
    'is_popular':
        row['is_popular'] == true ||
        row['is_popular_pick'] == true ||
        row['is_featured'] == true,
    'short_name': _firstString(row, const ['team_short_name', 'short_name']),
    'crest_url': _firstString(row, const [
      'team_crest_url',
      'crest_url',
      'logo_url',
    ]),
    'country_code': countryCode,
    'popular_rank': _firstInt(row, const [
      'popular_pick_rank',
      'sort_order',
      'display_order',
      'rank',
    ]),
  });
}

Future<List<Map<String, dynamic>>> _fetchAllActiveTeamRows(
  SupabaseClient client,
) async {
  Future<List<Map<String, dynamic>>> fetchPageSet(String selectColumns) async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var start = 0;

    while (true) {
      final page = await client
          .from('teams')
          .select(selectColumns)
          .eq('is_active', true)
          .order('name')
          .range(start, start + pageSize - 1);

      final normalized = (page as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
      if (normalized.isEmpty) break;

      rows.addAll(normalized);
      if (normalized.length < pageSize) break;
      start += pageSize;
    }

    return rows;
  }

  try {
    return await fetchPageSet(_teamCatalogSelectColumns);
  } catch (error) {
    AppLogger.d(
      'Startup: primary team catalog select failed, retrying legacy columns: $error',
    );
  }

  return fetchPageSet(_teamCatalogLegacySelectColumns);
}

List<String> _popularTableCandidates() {
  final configured = AppConfig.onboardingPopularTeamsTable.trim();
  final candidates = <String>[
    if (configured.isNotEmpty) configured,
    'onboarding_popular_teams',
    'popular_teams',
    'popular_team_picks',
  ];
  return candidates.toSet().toList(growable: false);
}

Future<List<OnboardingTeam>> _loadDedicatedPopularTeams(
  SupabaseClient client,
  BootstrapConfig config,
) async {
  for (final table in _popularTableCandidates()) {
    try {
      final rows = await client.from(table).select('*');
      final teams = (rows as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .where((row) => row['is_active'] != false)
          .map((row) => _mapTeamRow(row, config))
          .whereType<OnboardingTeam>()
          .toList(growable: false);
      if (teams.isNotEmpty) {
        return teams;
      }
    } catch (error) {
      AppLogger.d(
        'Startup: popular teams table "$table" unavailable, falling back: $error',
      );
    }
  }

  return const <OnboardingTeam>[];
}

Future<TeamSearchCatalog?> _buildRemoteTeamSearchCatalog(
  SupabaseClient client,
  BootstrapConfig config,
) async {
  final rows = await _fetchAllActiveTeamRows(client);
  final teams = rows
      .map((row) => _mapTeamRow(row, config))
      .whereType<OnboardingTeam>()
      .toList(growable: false);

  if (teams.isEmpty) return null;

  final popularTeams = await _loadDedicatedPopularTeams(client, config);
  return TeamSearchCatalog(teams, popularTeams: popularTeams);
}

Future<TeamSearchCatalog?> _loadRemoteTeamSearchCatalog(
  SupabaseConnection connection,
  BootstrapConfig config,
) async {
  final client = connection.client;
  if (client == null) return null;
  return _buildRemoteTeamSearchCatalog(client, config);
}

Future<TeamSearchCatalog?> _preloadRemoteTeamSearchCatalog(
  BootstrapConfig config,
) async {
  if (!AppConfig.hasSupabaseConfig) return null;
  final client = SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabaseAnonKey,
  );
  return _buildRemoteTeamSearchCatalog(client, config);
}

TeamSearchCatalog _mergeCatalogWithFallbackPopularTeams(
  TeamSearchCatalog catalog,
  TeamSearchCatalog fallbackCatalog,
) {
  if (catalog.popularTeams.isNotEmpty || fallbackCatalog.popularTeams.isEmpty) {
    return catalog;
  }

  return TeamSearchCatalog(
    catalog.allTeams,
    popularTeams: fallbackCatalog.popularTeams,
  );
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
      team_db.initTeamSearchDatabase(
        catalog: _mergeCatalogWithFallbackPopularTeams(
          remoteCatalog,
          team_db.activeTeamSearchCatalog,
        ),
      );
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

  final fallbackCatalog = TeamSearchCatalog.fromRawJson(
    await rootBundle.loadString('assets/data/team_search_database.json'),
  );

  // ── Team Catalog: DB-first, JSON-fallback ──
  // Try the teams table directly (the single source of truth).
  // Fall back to the bundled JSON asset only when the DB is unreachable
  // or the teams table is empty (e.g., first deploy before data sync).
  TeamSearchCatalog? catalog;
  try {
    catalog = await _preloadRemoteTeamSearchCatalog(config);
    if (catalog != null) {
      catalog = _mergeCatalogWithFallbackPopularTeams(catalog, fallbackCatalog);
    }
  } catch (e) {
    AppLogger.d(
      'Startup: DB team catalog load failed, falling back to JSON: $e',
    );
  }
  if (catalog == null || catalog.allTeams.isEmpty) {
    catalog = fallbackCatalog;
  }
  team_db.initTeamSearchDatabase(catalog: catalog);

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    teamSearchCatalogProvider.overrideWithValue(catalog),
    bootstrapConfigServiceProvider.overrideWith((ref) => bootstrapService),
  ];
}
