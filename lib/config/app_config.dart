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
  static const _onboardingPopularTeamsTableDefault = String.fromEnvironment(
    'ONBOARDING_POPULAR_TEAMS_TABLE',
  );

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

  static const _enablePredictionsDefault = bool.fromEnvironment(
    'ENABLE_PREDICTIONS',
    defaultValue: true,
  );
  static const _enableWalletDefault = bool.fromEnvironment(
    'ENABLE_WALLET',
    defaultValue: true,
  );
  static const _enableLeaderboardDefault = bool.fromEnvironment(
    'ENABLE_LEADERBOARD',
    defaultValue: true,
  );
  static const _enableRewardsDefault = bool.fromEnvironment(
    'ENABLE_REWARDS',
    defaultValue: true,
  );
  static const _enableMembershipDefault = bool.fromEnvironment(
    'ENABLE_MEMBERSHIP',
    defaultValue: false,
  );
  static const _enableNotificationsDefault = bool.fromEnvironment(
    'ENABLE_NOTIFICATIONS',
    defaultValue: false,
  );
  static const _enableTeamCommunitiesDefault = bool.fromEnvironment(
    'ENABLE_TEAM_COMMUNITIES',
    defaultValue: true,
  );

  // ── V2 Feature Flags ──

  static const _enableSocialFeedDefault = bool.fromEnvironment(
    'ENABLE_SOCIAL_FEED',
    defaultValue: false,
  );
  static const _enableFanIdentityDefault = bool.fromEnvironment(
    'ENABLE_FAN_IDENTITY',
    defaultValue: true,
  );
  static const _enableMarketplaceDefault = bool.fromEnvironment(
    'ENABLE_MARKETPLACE',
    defaultValue: true,
  );
  static const _enableAiAnalysisDefault = bool.fromEnvironment(
    'ENABLE_AI_ANALYSIS',
    defaultValue: false,
  );
  static const _enableAdvancedStatsDefault = bool.fromEnvironment(
    'ENABLE_ADVANCED_STATS',
    defaultValue: false,
  );
  static const _enableCommunityContestsDefault = bool.fromEnvironment(
    'ENABLE_COMMUNITY_CONTESTS',
    defaultValue: false,
  );
  static const _enableSeasonalLeaderboardsDefault = bool.fromEnvironment(
    'ENABLE_SEASONAL_LEADERBOARDS',
    defaultValue: false,
  );
  static const _enableDeepLinkingDefault = bool.fromEnvironment(
    'ENABLE_DEEP_LINKING',
    defaultValue: true,
  );

  // ── Global Launch Feature Flags ──

  static const _enableFeaturedEventsDefault = bool.fromEnvironment(
    'ENABLE_FEATURED_EVENTS',
    defaultValue: true,
  );
  static const _enableGlobalChallengesDefault = bool.fromEnvironment(
    'ENABLE_GLOBAL_CHALLENGES',
    defaultValue: false,
  );
  static const _enableRegionDiscoveryDefault = bool.fromEnvironment(
    'ENABLE_REGION_DISCOVERY',
    defaultValue: true,
  );

  static bool _featureFlag(String key, bool defaultValue) =>
      runtimeBootstrapStore.config.featureFlags[key] ?? defaultValue;

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

  static bool get enablePredictions =>
      _featureFlag('predictions', _enablePredictionsDefault);
  static bool get enableWallet => _featureFlag('wallet', _enableWalletDefault);
  static bool get enableLeaderboard =>
      _featureFlag('leaderboard', _enableLeaderboardDefault);
  static bool get enableRewards =>
      _featureFlag('rewards', _enableRewardsDefault);
  static bool get enableMembership =>
      _featureFlag('membership', _enableMembershipDefault);
  static bool get enableNotifications =>
      _featureFlag('notifications', _enableNotificationsDefault);
  static bool get enableTeamCommunities =>
      _featureFlag('team_communities', _enableTeamCommunitiesDefault);

  static bool get enableSocialFeed =>
      _featureFlag('social_feed', _enableSocialFeedDefault);
  static bool get enableFanIdentity =>
      _featureFlag('fan_identity', _enableFanIdentityDefault);
  static bool get enableMarketplace =>
      _featureFlag('marketplace', _enableMarketplaceDefault);
  static bool get enableAiAnalysis =>
      _featureFlag('ai_analysis', _enableAiAnalysisDefault);
  static bool get enableAdvancedStats =>
      _featureFlag('advanced_stats', _enableAdvancedStatsDefault);
  static bool get enableCommunityContests =>
      _featureFlag('community_contests', _enableCommunityContestsDefault);
  static bool get enableSeasonalLeaderboards =>
      _featureFlag('seasonal_leaderboards', _enableSeasonalLeaderboardsDefault);
  static bool get enableDeepLinking =>
      _featureFlag('deep_linking', _enableDeepLinkingDefault);

  static bool get enableFeaturedEvents =>
      _featureFlag('featured_events', _enableFeaturedEventsDefault);
  static bool get enableGlobalChallenges =>
      _featureFlag('global_challenges', _enableGlobalChallengesDefault);
  static bool get enableRegionDiscovery =>
      _featureFlag('region_discovery', _enableRegionDiscoveryDefault);

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
  static String get onboardingPopularTeamsTable =>
      (_remoteConfigValue<String>(
            'onboarding_popular_teams_table',
          )?.trim().isNotEmpty ??
          false)
      ? _remoteConfigValue<String>('onboarding_popular_teams_table')!.trim()
      : _onboardingPopularTeamsTableDefault;
  static bool get hasImageCdn => imageCdnBaseUrl.trim().startsWith('http');
  static bool get hasStaticCdn => staticCdnBaseUrl.trim().startsWith('http');
}
