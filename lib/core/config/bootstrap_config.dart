import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../cache/cache_service.dart';
import '../logging/app_logger.dart';
import '../supabase/supabase_connection.dart';

/// Runtime bootstrap configuration loaded from Supabase at app startup.
///
/// Replaces all hardcoded country/region/currency/phone/feature-flag
/// constants with database-driven values.  Falls back to cached data
/// when offline, and to compiled defaults only on first-ever cold start.
class BootstrapConfig {
  BootstrapConfig({
    required this.regions,
    required this.phonePresets,
    required this.currencyDisplay,
    required this.countryCurrencies,
    required this.featureFlags,
    required this.appConfig,
    required this.launchMoments,
    required this.platformFeatures,
    required this.platformContentBlocks,
  });

  factory BootstrapConfig.fromJson(Map<String, dynamic> json) {
    return BootstrapConfig(
      regions: _parseRegions(json['regions']),
      phonePresets: _parsePhonePresets(json['phone_presets']),
      currencyDisplay: _parseCurrencyDisplay(json['currency_display']),
      countryCurrencies: _parseCountryCurrencies(
        json['country_currency_map'] ?? json['country_currencies'],
      ),
      featureFlags: _parseFeatureFlags(json['feature_flags']),
      appConfig: Map<String, dynamic>.from(json['app_config'] ?? {}),
      launchMoments: _parseLaunchMoments(json['launch_moments']),
      platformFeatures: _parsePlatformFeatures(json['platform_features']),
      platformContentBlocks: _parsePlatformContentBlocks(
        json['platform_content_blocks'],
      ),
    );
  }

  /// Empty config used when no data is available.
  factory BootstrapConfig.empty() {
    return BootstrapConfig(
      regions: const {},
      phonePresets: const {},
      currencyDisplay: const {},
      countryCurrencies: const {},
      featureFlags: const {},
      appConfig: const {},
      launchMoments: const [],
      platformFeatures: const [],
      platformContentBlocks: const [],
    );
  }

  /// Country code → region info.
  final Map<String, RegionInfo> regions;

  /// Country code → phone preset.
  final Map<String, PhonePresetInfo> phonePresets;

  /// Currency code → display metadata.
  final Map<String, CurrencyDisplayInfo> currencyDisplay;

  /// Country code → preferred currency code.
  final Map<String, String> countryCurrencies;

  /// Feature flag key → enabled.
  final Map<String, bool> featureFlags;

  /// Remote app config key → value.
  final Map<String, dynamic> appConfig;

  /// Active launch moments.
  final List<LaunchMomentInfo> launchMoments;

  /// Channel-aware feature registry.
  final List<PlatformFeatureInfo> platformFeatures;

  /// Admin-managed content blocks used for home and entry-point composition.
  final List<PlatformContentBlockInfo> platformContentBlocks;

  // ── Region helpers ──

  String regionForCountryCode(String? code) {
    if (code == null || code.isEmpty) return 'global';
    return _normalizeRegion(regions[code.toUpperCase()]?.region);
  }

  String flagEmojiForCountryCode(String? code) {
    if (code == null || code.isEmpty) return '🌍';
    return regions[code.toUpperCase()]?.flagEmoji ?? '🌍';
  }

  String? countryNameForCode(String? code) {
    if (code == null || code.isEmpty) return null;
    return regions[code.toUpperCase()]?.countryName;
  }

  String flagEmojiForCountryName(String? name) {
    if (name == null || name.isEmpty) return '🌍';
    for (final entry in regions.values) {
      if (entry.countryName.toLowerCase() == name.toLowerCase()) {
        return entry.flagEmoji;
      }
    }
    return '🌍';
  }

  List<String> countryCodesForRegion(String region) {
    final normalized = _normalizeRegion(region);
    return regions.entries
        .where((entry) => _normalizeRegion(entry.value.region) == normalized)
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  List<String> countryNamesForRegion(String region) {
    final normalized = _normalizeRegion(region);
    return regions.entries
        .where((entry) => _normalizeRegion(entry.value.region) == normalized)
        .map((entry) => entry.value.countryName)
        .toList(growable: false)
      ..sort();
  }

  String? currencyForCountryCode(String? code) {
    if (code == null || code.isEmpty) return null;
    return countryCurrencies[code.toUpperCase()];
  }

  // ── Phone helpers ──

  PhonePresetInfo? phonePresetForCountry(String? code) {
    if (code == null || code.isEmpty) return null;
    return phonePresets[code.toUpperCase()];
  }

  PhonePresetInfo phonePresetForRegion(String region) {
    final normalized = _normalizeRegion(region);
    if (phonePresets.isNotEmpty) {
      final regionCandidates =
          phonePresets.entries
              .where(
                (entry) =>
                    _normalizeRegion(regions[entry.key]?.region) == normalized,
              )
              .toList(growable: false)
            ..sort((left, right) {
              final leftName = regions[left.key]?.countryName ?? left.key;
              final rightName = regions[right.key]?.countryName ?? right.key;
              return leftName.compareTo(rightName);
            });

      if (regionCandidates.isNotEmpty) {
        return regionCandidates.first.value;
      }

      final allCandidates = phonePresets.entries.toList(growable: false)
        ..sort((left, right) {
          final leftName = regions[left.key]?.countryName ?? left.key;
          final rightName = regions[right.key]?.countryName ?? right.key;
          return leftName.compareTo(rightName);
        });

      return allCandidates.first.value;
    }

    return const PhonePresetInfo(
      dialCode: '+',
      hint: '000 000 000',
      minDigits: 7,
    );
  }

  // ── Feature flag helpers ──

  bool isFeatureEnabled(String key, {bool defaultValue = false}) {
    return featureFlags[key] ?? defaultValue;
  }

  PlatformFeatureInfo? platformFeature(String key) {
    final normalized = key.trim().toLowerCase();
    for (final feature in platformFeatures) {
      if (feature.featureKey == normalized) {
        return feature;
      }
    }
    return null;
  }

  List<PlatformContentBlockInfo> contentBlocksForChannel(
    String channel, {
    String? placementKey,
  }) {
    final normalizedChannel = channel.trim().toLowerCase();
    final normalizedPlacement = placementKey?.trim().toLowerCase();

    return platformContentBlocks
        .where((block) {
          if (!block.isActive) return false;
          if (block.targetChannel != 'both' &&
              block.targetChannel != normalizedChannel) {
            return false;
          }
          if (normalizedPlacement != null &&
              block.placementKey != normalizedPlacement) {
            return false;
          }
          return true;
        })
        .toList(growable: false)
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  }

  // ── App config helpers ──

  T? configValue<T>(String key) {
    final value = appConfig[key];
    if (value is T) return value;
    return null;
  }

  // ── Serialization ──

  Map<String, dynamic> toJson() {
    return {
      'regions': regions.entries
          .map((entry) => entry.value.toJson())
          .toList(growable: false),
      'phone_presets': phonePresets.entries
          .map((entry) => entry.value.toJson()..['country_code'] = entry.key)
          .toList(growable: false),
      'currency_display': currencyDisplay.entries
          .map((entry) => entry.value.toJson()..['currency_code'] = entry.key)
          .toList(growable: false),
      'country_currency_map': countryCurrencies.entries
          .map(
            (entry) => {
              'country_code': entry.key,
              'currency_code': entry.value,
            },
          )
          .toList(growable: false),
      'feature_flags': featureFlags,
      'app_config': appConfig,
      'launch_moments': launchMoments
          .map((moment) => moment.toJson())
          .toList(growable: false),
      'platform_features': platformFeatures
          .map((feature) => feature.toJson())
          .toList(growable: false),
      'platform_content_blocks': platformContentBlocks
          .map((block) => block.toJson())
          .toList(growable: false),
    };
  }

  // ── Private parsers ──

  static Map<String, RegionInfo> _parseRegions(dynamic data) {
    if (data is! List) return const {};
    final result = <String, RegionInfo>{};
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final code = item['country_code']?.toString().toUpperCase();
        if (code != null && code.isNotEmpty) {
          result[code] = RegionInfo.fromJson(item);
        }
      }
    }
    return result;
  }

  static String _normalizeRegion(String? region) {
    switch ((region ?? '').trim().toLowerCase()) {
      case 'africa':
        return 'africa';
      case 'europe':
        return 'europe';
      case 'americas':
      case 'north_america':
      case 'northamerica':
        return 'north_america';
      default:
        return 'global';
    }
  }

  static Map<String, PhonePresetInfo> _parsePhonePresets(dynamic data) {
    if (data is! List) return const {};
    final result = <String, PhonePresetInfo>{};
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final code = item['country_code']?.toString().toUpperCase();
        if (code != null && code.isNotEmpty) {
          result[code] = PhonePresetInfo.fromJson(item);
        }
      }
    }
    return result;
  }

  static Map<String, CurrencyDisplayInfo> _parseCurrencyDisplay(dynamic data) {
    if (data is! List) return const {};
    final result = <String, CurrencyDisplayInfo>{};
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final code = item['currency_code']?.toString().toUpperCase();
        if (code != null && code.isNotEmpty) {
          result[code] = CurrencyDisplayInfo.fromJson(item);
        }
      }
    }
    return result;
  }

  static Map<String, String> _parseCountryCurrencies(dynamic data) {
    if (data is! List) return const {};
    final result = <String, String>{};
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final countryCode = item['country_code']?.toString().toUpperCase();
        final currencyCode = item['currency_code']?.toString().toUpperCase();
        if (countryCode != null &&
            countryCode.isNotEmpty &&
            currencyCode != null &&
            currencyCode.isNotEmpty) {
          result[countryCode] = currencyCode;
        }
      }
    }
    return result;
  }

  static Map<String, bool> _parseFeatureFlags(dynamic data) {
    if (data is! Map) return const {};
    final result = <String, bool>{};
    for (final entry in data.entries) {
      result[entry.key.toString()] = entry.value == true;
    }
    return result;
  }

  static List<LaunchMomentInfo> _parseLaunchMoments(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(LaunchMomentInfo.fromJson)
        .toList(growable: false);
  }

  static List<PlatformFeatureInfo> _parsePlatformFeatures(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PlatformFeatureInfo.fromJson)
        .toList(growable: false);
  }

  static List<PlatformContentBlockInfo> _parsePlatformContentBlocks(
    dynamic data,
  ) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PlatformContentBlockInfo.fromJson)
        .toList(growable: false);
  }
}

/// Region information for a single country.
class RegionInfo {
  const RegionInfo({
    required this.countryCode,
    required this.region,
    required this.countryName,
    required this.flagEmoji,
  });

  factory RegionInfo.fromJson(Map<String, dynamic> json) {
    return RegionInfo(
      countryCode: json['country_code']?.toString() ?? '',
      region: json['region']?.toString() ?? 'global',
      countryName: json['country_name']?.toString() ?? '',
      flagEmoji: json['flag_emoji']?.toString() ?? '🌍',
    );
  }

  final String countryCode;
  final String region;
  final String countryName;
  final String flagEmoji;

  Map<String, dynamic> toJson() => {
    'country_code': countryCode,
    'region': region,
    'country_name': countryName,
    'flag_emoji': flagEmoji,
  };
}

/// Phone number input preset for a country.
class PhonePresetInfo {
  const PhonePresetInfo({
    required this.dialCode,
    required this.hint,
    required this.minDigits,
  });

  factory PhonePresetInfo.fromJson(Map<String, dynamic> json) {
    return PhonePresetInfo(
      dialCode: json['dial_code']?.toString() ?? '+1',
      hint: json['hint']?.toString() ?? 'XXX XXX XXXX',
      minDigits: (json['min_digits'] as num?)?.toInt() ?? 9,
    );
  }

  final String dialCode;
  final String hint;
  final int minDigits;

  String get example => '$dialCode $hint';

  Map<String, dynamic> toJson() => {
    'dial_code': dialCode,
    'hint': hint,
    'min_digits': minDigits,
  };
}

/// Currency display formatting metadata.
class CurrencyDisplayInfo {
  const CurrencyDisplayInfo({
    required this.symbol,
    this.decimals = 2,
    this.spaceSeparated = false,
  });

  factory CurrencyDisplayInfo.fromJson(Map<String, dynamic> json) {
    return CurrencyDisplayInfo(
      symbol: json['symbol']?.toString() ?? '?',
      decimals: (json['decimals'] as num?)?.toInt() ?? 2,
      spaceSeparated: json['space_separated'] == true,
    );
  }

  final String symbol;
  final int decimals;
  final bool spaceSeparated;

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'decimals': decimals,
    'space_separated': spaceSeparated,
  };
}

/// A marketing launch moment.
class LaunchMomentInfo {
  const LaunchMomentInfo({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.kicker,
    required this.regionKey,
  });

  factory LaunchMomentInfo.fromJson(Map<String, dynamic> json) {
    return LaunchMomentInfo(
      tag: json['tag']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      kicker: json['kicker']?.toString() ?? '',
      regionKey: json['region_key']?.toString() ?? 'global',
    );
  }

  final String tag;
  final String title;
  final String subtitle;
  final String kicker;
  final String regionKey;

  Map<String, dynamic> toJson() => {
    'tag': tag,
    'title': title,
    'subtitle': subtitle,
    'kicker': kicker,
    'region_key': regionKey,
  };
}

class PlatformFeatureChannelInfo {
  const PlatformFeatureChannelInfo({
    required this.channel,
    required this.isVisible,
    required this.isEnabled,
    required this.showInNavigation,
    required this.showOnHome,
    required this.sortOrder,
    this.routeKey,
    this.entryKey,
    this.navigationLabel,
    this.placementKey,
    this.metadata = const {},
  });

  factory PlatformFeatureChannelInfo.fromJson(
    Map<String, dynamic> json, {
    required String fallbackChannel,
  }) {
    return PlatformFeatureChannelInfo(
      channel:
          json['channel']?.toString().trim().toLowerCase().isNotEmpty == true
          ? json['channel'].toString().trim().toLowerCase()
          : fallbackChannel,
      isVisible: json['is_visible'] == true,
      isEnabled: json['is_enabled'] == true,
      showInNavigation: json['show_in_navigation'] == true,
      showOnHome: json['show_on_home'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      routeKey: json['route_key']?.toString(),
      entryKey: json['entry_key']?.toString(),
      navigationLabel: json['navigation_label']?.toString(),
      placementKey: json['placement_key']?.toString(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  final String channel;
  final bool isVisible;
  final bool isEnabled;
  final bool showInNavigation;
  final bool showOnHome;
  final int sortOrder;
  final String? routeKey;
  final String? entryKey;
  final String? navigationLabel;
  final String? placementKey;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'channel': channel,
    'is_visible': isVisible,
    'is_enabled': isEnabled,
    'show_in_navigation': showInNavigation,
    'show_on_home': showOnHome,
    'sort_order': sortOrder,
    'route_key': routeKey,
    'entry_key': entryKey,
    'navigation_label': navigationLabel,
    'placement_key': placementKey,
    'metadata': metadata,
  };
}

class PlatformFeatureResolvedState {
  const PlatformFeatureResolvedState({
    required this.isOperational,
    required this.isVisible,
    required this.isAvailable,
    required this.showInNavigation,
    required this.showOnHome,
    this.routeKey,
    this.entryKey,
    this.sortOrder = 100,
  });

  factory PlatformFeatureResolvedState.fromJson(Map<String, dynamic> json) {
    return PlatformFeatureResolvedState(
      isOperational: json['is_operational'] == true,
      isVisible: json['is_visible'] == true,
      isAvailable: json['is_available'] == true,
      showInNavigation: json['show_in_navigation'] == true,
      showOnHome: json['show_on_home'] == true,
      routeKey: json['route_key']?.toString(),
      entryKey: json['entry_key']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
    );
  }

  final bool isOperational;
  final bool isVisible;
  final bool isAvailable;
  final bool showInNavigation;
  final bool showOnHome;
  final String? routeKey;
  final String? entryKey;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'is_operational': isOperational,
    'is_visible': isVisible,
    'is_available': isAvailable,
    'show_in_navigation': showInNavigation,
    'show_on_home': showOnHome,
    'route_key': routeKey,
    'entry_key': entryKey,
    'sort_order': sortOrder,
  };
}

class PlatformFeatureInfo {
  const PlatformFeatureInfo({
    required this.featureKey,
    required this.displayName,
    required this.description,
    required this.status,
    required this.isEnabled,
    required this.navigationGroup,
    required this.defaultRouteKey,
    required this.authRequired,
    required this.channels,
    required this.resolvedState,
  });

  factory PlatformFeatureInfo.fromJson(Map<String, dynamic> json) {
    final channels = Map<String, dynamic>.from(json['channels'] ?? {});
    return PlatformFeatureInfo(
      featureKey: json['feature_key']?.toString().trim().toLowerCase() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString().trim().toLowerCase() ?? 'inactive',
      isEnabled: json['is_enabled'] == true,
      navigationGroup: json['navigation_group']?.toString(),
      defaultRouteKey: json['default_route_key']?.toString(),
      authRequired: json['auth_required'] == true,
      channels: {
        'mobile': PlatformFeatureChannelInfo.fromJson(
          Map<String, dynamic>.from(channels['mobile'] ?? {}),
          fallbackChannel: 'mobile',
        ),
        'web': PlatformFeatureChannelInfo.fromJson(
          Map<String, dynamic>.from(channels['web'] ?? {}),
          fallbackChannel: 'web',
        ),
      },
      resolvedState: PlatformFeatureResolvedState.fromJson(
        Map<String, dynamic>.from(json['resolved_state'] ?? {}),
      ),
    );
  }

  final String featureKey;
  final String displayName;
  final String? description;
  final String status;
  final bool isEnabled;
  final String? navigationGroup;
  final String? defaultRouteKey;
  final bool authRequired;
  final Map<String, PlatformFeatureChannelInfo> channels;
  final PlatformFeatureResolvedState resolvedState;

  PlatformFeatureChannelInfo channel(String channelKey) {
    return channels[channelKey] ??
        PlatformFeatureChannelInfo.fromJson(
          const {},
          fallbackChannel: channelKey,
        );
  }

  Map<String, dynamic> toJson() => {
    'feature_key': featureKey,
    'display_name': displayName,
    'description': description,
    'status': status,
    'is_enabled': isEnabled,
    'navigation_group': navigationGroup,
    'default_route_key': defaultRouteKey,
    'auth_required': authRequired,
    'channels': {
      for (final entry in channels.entries) entry.key: entry.value.toJson(),
    },
    'resolved_state': resolvedState.toJson(),
  };
}

class PlatformContentBlockInfo {
  const PlatformContentBlockInfo({
    required this.blockKey,
    required this.blockType,
    required this.title,
    required this.content,
    required this.targetChannel,
    required this.isActive,
    required this.sortOrder,
    required this.placementKey,
    this.featureKey,
    this.metadata = const {},
  });

  factory PlatformContentBlockInfo.fromJson(Map<String, dynamic> json) {
    return PlatformContentBlockInfo(
      blockKey: json['block_key']?.toString().trim().toLowerCase() ?? '',
      blockType: json['block_type']?.toString().trim().toLowerCase() ?? '',
      title: json['title']?.toString() ?? '',
      content: Map<String, dynamic>.from(json['content'] ?? {}),
      targetChannel:
          json['target_channel']?.toString().trim().toLowerCase() ?? 'both',
      isActive: json['is_active'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      placementKey:
          json['placement_key']?.toString().trim().toLowerCase() ?? '',
      featureKey: json['feature_key']?.toString().trim().toLowerCase(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  final String blockKey;
  final String blockType;
  final String title;
  final Map<String, dynamic> content;
  final String targetChannel;
  final bool isActive;
  final int sortOrder;
  final String placementKey;
  final String? featureKey;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'block_key': blockKey,
    'block_type': blockType,
    'title': title,
    'content': content,
    'target_channel': targetChannel,
    'is_active': isActive,
    'sort_order': sortOrder,
    'placement_key': placementKey,
    'feature_key': featureKey,
    'metadata': metadata,
  };
}

/// Service that loads and caches the bootstrap config from Supabase.
class BootstrapConfigService extends ChangeNotifier {
  BootstrapConfigService(this._cache, this._connection);

  static const _cacheKey = 'bootstrap_config_v2';

  final CacheService _cache;
  final SupabaseConnection _connection;

  BootstrapConfig? _current;

  /// The currently loaded config.  Never null after [load] completes.
  BootstrapConfig get config => _current ?? BootstrapConfig.empty();

  /// Load only cached config (or empty) without touching the network.
  ///
  /// This is used on the startup critical path so the app can paint from
  /// local state first and refresh from Supabase in the background.
  Future<BootstrapConfig> loadCached() async {
    return _loadCachedOrEmpty();
  }

  /// Load config: try Supabase RPC → fall back to cache → fall back to empty.
  Future<BootstrapConfig> load({
    String market = 'global',
    String platform = 'all',
  }) async {
    // 1. Try remote
    try {
      final client = _connection.client;
      if (client != null) {
        final result = await client
            .rpc(
              'get_app_bootstrap_config',
              params: {'p_market': market, 'p_platform': platform},
            )
            .timeout(const Duration(seconds: 8));

        if (result != null) {
          final data = result is String
              ? jsonDecode(result) as Map<String, dynamic>
              : Map<String, dynamic>.from(result as Map);
          _current = BootstrapConfig.fromJson(data);
          await _cache.setJson(_cacheKey, _current!.toJson());
          notifyListeners();
          AppLogger.d(
            'Bootstrap config loaded from Supabase: '
            '${_current!.regions.length} regions, '
            '${_current!.phonePresets.length} phone presets, '
            '${_current!.featureFlags.length} flags',
          );
          return _current!;
        }
      }
    } catch (error) {
      AppLogger.d('Failed to load bootstrap config from Supabase: $error');
    }

    // 2. Try cache / empty fallback
    return _loadCachedOrEmpty();
  }

  /// Force refresh from remote.
  Future<BootstrapConfig> refresh({
    String market = 'global',
    String platform = 'all',
  }) async {
    return load(market: market, platform: platform);
  }

  Future<BootstrapConfig> _loadCachedOrEmpty() async {
    try {
      final cached = await _cache.getJsonMap(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _current = BootstrapConfig.fromJson(cached);
        notifyListeners();
        AppLogger.d(
          'Bootstrap config loaded from cache: '
          '${_current!.regions.length} regions',
        );
        return _current!;
      }
    } catch (error) {
      if (kDebugMode) {
        AppLogger.d('Failed to load cached bootstrap config: $error');
      }
    }

    _current = BootstrapConfig.empty();
    notifyListeners();
    return _current!;
  }
}
