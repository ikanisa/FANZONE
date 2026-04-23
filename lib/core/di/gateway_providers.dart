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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Core layer ─────────────────────────────────────────────
import '../cache/cache_service.dart';
import '../cache/shared_preferences_cache_service.dart';
import '../supabase/supabase_connection.dart';
import '../utils/team_name_cleanup.dart';

// ── Feature gateways ───────────────────────────────────────
import '../../features/auth/data/auth_gateway.dart';
import '../../data/team_search_database.dart';
import '../../features/home/data/catalog_gateway.dart';
import '../../features/home/data/match_listing_gateway.dart';
import '../../features/onboarding/data/onboarding_gateway.dart';
import '../../features/predict/data/leaderboard_gateway.dart';
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
  Map<String, dynamic>? sanitizeTeamRow(Map<String, dynamic> row) {
    final rawName = _firstString(row, const ['team_name', 'name']);
    if (rawName == null || isPlaceholderTeamName(rawName)) {
      return null;
    }

    final sanitized = Map<String, dynamic>.from(row);
    sanitized['name'] = normalizeTeamDisplayName(rawName);

    final rawShortName = _firstString(row, const [
      'team_short_name',
      'short_name',
    ]);
    if (rawShortName != null) {
      sanitized['short_name'] = normalizeTeamDisplayName(rawShortName);
    }

    return sanitized;
  }

  Future<List<Map<String, dynamic>>> fetchPageSet(
    String table,
    String selectColumns,
  ) async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var start = 0;

    while (true) {
      final page = await client
          .from(table)
          .select(selectColumns)
          .eq('is_active', true)
          .order('name')
          .range(start, start + pageSize - 1);

      final normalized = (page as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
      if (normalized.isEmpty) break;

      rows.addAll(
        normalized
            .map(sanitizeTeamRow)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );
      if (normalized.length < pageSize) break;
      start += pageSize;
    }

    return rows;
  }

  return fetchPageSet('teams', _teamCatalogSelectColumns);
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

  final popularTeams =
      rows
          .where(
            (row) =>
                row['is_popular_pick'] == true || row['is_featured'] == true,
          )
          .map((row) => _mapTeamRow(row, config))
          .whereType<OnboardingTeam>()
          .toList(growable: false)
        ..sort((left, right) {
          final leftRank = left.popularRank ?? 9999;
          final rightRank = right.popularRank ?? 9999;
          if (leftRank != rightRank) {
            return leftRank.compareTo(rightRank);
          }
          return left.name.compareTo(right.name);
        });
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
      initTeamSearchDatabase(catalog: remoteCatalog);
    }
  } catch (_) {
    // Keep the current runtime catalog when the live data plane is unavailable.
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

final leaderboardGatewayProvider = Provider<LeaderboardGateway>((ref) {
  return SupabaseLeaderboardGateway(ref.watch(supabaseConnectionProvider));
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

/// Call this during app startup to resolve local async singletons,
/// then pass the results as ProviderScope overrides.
///
/// This path must stay fast and offline-safe. Remote bootstrap and live team
/// catalog hydration happen after Supabase comes up.
Future<List<Override>> resolveAsyncOverrides() async {
  final prefs = await SharedPreferences.getInstance();

  // Initialize global singletons for static services outside Riverpod scope
  SharedPreferencesCacheService.initGlobal(prefs);

  // Load bootstrap config from cache only; remote refresh happens later.
  final cacheService = SharedPreferencesCacheService(prefs);
  final connection = SupabaseConnectionImpl();
  final bootstrapService = BootstrapConfigService(cacheService, connection);
  final config = await bootstrapService.loadCached();
  _bootstrapRuntimeService = bootstrapService;
  _bootstrapRuntimeConnection = connection;

  _applyRuntimeBootstrap(config);

  // Team search catalog starts empty and hydrates from Supabase after startup.
  final catalog = TeamSearchCatalog.empty();
  initTeamSearchDatabase(catalog: catalog);

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    teamSearchCatalogProvider.overrideWithValue(catalog),
    bootstrapConfigServiceProvider.overrideWith((ref) => bootstrapService),
  ];
}
