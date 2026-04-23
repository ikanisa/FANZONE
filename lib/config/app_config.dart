import 'package:flutter/foundation.dart';

import '../core/config/runtime_bootstrap.dart';

enum AppEnvironment { development, staging, production }

/// Build-time application configuration loaded via `--dart-define`.
class AppConfig {
  static const appName = 'FANZONE';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.1.0',
  );
  static const environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const _imageCdnBaseUrlDefault = String.fromEnvironment(
    'IMAGE_CDN_BASE_URL',
  );
  static const _staticCdnBaseUrlDefault = String.fromEnvironment(
    'STATIC_CDN_BASE_URL',
  );
  static const _staticAssetVersionDefault = String.fromEnvironment(
    'STATIC_ASSET_VERSION',
    defaultValue: '1',
  );

  static bool _featureFlag(String key) =>
      runtimeBootstrapStore.config.featureFlags[key] == true;

  static T? _remoteConfigValue<T>(String key) {
    final value = runtimeBootstrapStore.config.appConfig[key];
    if (value is T) return value;
    return null;
  }

  static String get imageCdnBaseUrl =>
      (_remoteConfigValue<String>('image_cdn_base_url')?.trim().isNotEmpty ??
          false)
      ? _remoteConfigValue<String>('image_cdn_base_url')!.trim()
      : _imageCdnBaseUrlDefault;

  static String get staticCdnBaseUrl =>
      (_remoteConfigValue<String>('static_cdn_base_url')?.trim().isNotEmpty ??
          false)
      ? _remoteConfigValue<String>('static_cdn_base_url')!.trim()
      : _staticCdnBaseUrlDefault;

  static String get staticAssetVersion => (() {
    final stringValue = _remoteConfigValue<String>(
      'static_asset_version',
    )?.trim();
    if (stringValue != null && stringValue.isNotEmpty) return stringValue;
    final numericValue = _remoteConfigValue<num>('static_asset_version');
    if (numericValue != null) return numericValue.toString();
    return _staticAssetVersionDefault;
  })();

  static bool get enablePredictions => _featureFlag('predictions');
  static bool get enableWallet => _featureFlag('wallet');
  static bool get enableLeaderboard => _featureFlag('leaderboard');
  static bool get enableRewards => _featureFlag('rewards');
  static bool get enableNotifications => _featureFlag('notifications');

  static bool get enableDeepLinking => _featureFlag('deep_linking');

  static bool get enableFeaturedEvents => _featureFlag('featured_events');
  static bool get enableRegionDiscovery => _featureFlag('region_discovery');

  static AppEnvironment get environment {
    switch (environmentName.toLowerCase()) {
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isProduction => environment == AppEnvironment.production;
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasImageCdn => imageCdnBaseUrl.trim().startsWith('http');
  static bool get hasStaticCdn => staticCdnBaseUrl.trim().startsWith('http');
}
