import 'package:flutter/foundation.dart';

enum AppEnvironment { development, staging, production }

/// Build-time application configuration loaded via `--dart-define`.
class AppConfig {
  static const appName = 'FANZONE';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const imageCdnBaseUrl = String.fromEnvironment('IMAGE_CDN_BASE_URL');
  static const staticCdnBaseUrl = String.fromEnvironment('STATIC_CDN_BASE_URL');
  static const staticAssetVersion = String.fromEnvironment(
    'STATIC_ASSET_VERSION',
    defaultValue: '1',
  );

  static const enablePredictions = bool.fromEnvironment(
    'ENABLE_PREDICTIONS',
    defaultValue: true,
  );
  static const enableWallet = bool.fromEnvironment(
    'ENABLE_WALLET',
    defaultValue: true,
  );
  static const enableLeaderboard = bool.fromEnvironment(
    'ENABLE_LEADERBOARD',
    defaultValue: true,
  );
  static const enableRewards = bool.fromEnvironment(
    'ENABLE_REWARDS',
    defaultValue: true,
  );
  static const enableMembership = bool.fromEnvironment(
    'ENABLE_MEMBERSHIP',
    defaultValue: false,
  );
  static const enableNotifications = bool.fromEnvironment(
    'ENABLE_NOTIFICATIONS',
    defaultValue: false,
  );
  static const enableTeamCommunities = bool.fromEnvironment(
    'ENABLE_TEAM_COMMUNITIES',
    defaultValue: true,
  );

  // ── V2 Feature Flags ──

  static const enableSocialFeed = bool.fromEnvironment(
    'ENABLE_SOCIAL_FEED',
    defaultValue: false,
  );
  static const enableFanIdentity = bool.fromEnvironment(
    'ENABLE_FAN_IDENTITY',
    defaultValue: true,
  );
  static const enableMarketplace = bool.fromEnvironment(
    'ENABLE_MARKETPLACE',
    defaultValue: true,
  );
  static const enableAiAnalysis = bool.fromEnvironment(
    'ENABLE_AI_ANALYSIS',
    defaultValue: false,
  );
  static const enableAdvancedStats = bool.fromEnvironment(
    'ENABLE_ADVANCED_STATS',
    defaultValue: false,
  );
  static const enableCommunityContests = bool.fromEnvironment(
    'ENABLE_COMMUNITY_CONTESTS',
    defaultValue: false,
  );
  static const enableSeasonalLeaderboards = bool.fromEnvironment(
    'ENABLE_SEASONAL_LEADERBOARDS',
    defaultValue: false,
  );
  static const enableDeepLinking = bool.fromEnvironment(
    'ENABLE_DEEP_LINKING',
    defaultValue: true,
  );

  // ── Global Launch Feature Flags ──

  static const enableFeaturedEvents = bool.fromEnvironment(
    'ENABLE_FEATURED_EVENTS',
    defaultValue: true,
  );
  static const enableGlobalChallenges = bool.fromEnvironment(
    'ENABLE_GLOBAL_CHALLENGES',
    defaultValue: false,
  );
  static const enableRegionDiscovery = bool.fromEnvironment(
    'ENABLE_REGION_DISCOVERY',
    defaultValue: true,
  );

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

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasImageCdn => imageCdnBaseUrl.trim().startsWith('http');
  static bool get hasStaticCdn => staticCdnBaseUrl.trim().startsWith('http');
  static bool get hasSentry {
    final normalized = sentryDsn.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized.startsWith('replace_')) return false;
    if (normalized.contains('replace-with')) return false;
    return normalized.startsWith('http');
  }
}
