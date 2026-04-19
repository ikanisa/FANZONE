/// Runtime feature flags service that layers DB-driven flags over
/// compile-time [AppConfig] defaults.
///
/// Load order:
///   1. Compile-time `--dart-define` defaults (always available)
///   2. DB-driven flags from `feature_flags` table via [BootstrapConfig]
///   3. DB flags override compile-time flags when present
///
/// Usage:
///   ```dart
///   final flags = ref.read(featureFlagsProvider);
///   if (flags.predictions) { ... }
///   ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../config/bootstrap_config.dart';
import '../di/gateway_providers.dart';

class FeatureFlags {
  const FeatureFlags(this._bootstrapConfig);

  final BootstrapConfig _bootstrapConfig;

  /// Check a DB flag first, fall back to compile-time default.
  bool _flag(String key, bool compileTimeDefault) =>
      _bootstrapConfig.featureFlags[key] ?? compileTimeDefault;

  // ── Core Features ──

  bool get predictions => _flag('predictions', AppConfig.enablePredictions);
  bool get wallet => _flag('wallet', AppConfig.enableWallet);
  bool get leaderboard => _flag('leaderboard', AppConfig.enableLeaderboard);
  bool get rewards => _flag('rewards', AppConfig.enableRewards);
  bool get membership => _flag('membership', AppConfig.enableMembership);
  bool get notifications =>
      _flag('notifications', AppConfig.enableNotifications);
  bool get teamCommunities =>
      _flag('team_communities', AppConfig.enableTeamCommunities);

  // ── V2 Features ──

  bool get socialFeed => _flag('social_feed', AppConfig.enableSocialFeed);
  bool get fanIdentity => _flag('fan_identity', AppConfig.enableFanIdentity);
  bool get marketplace => _flag('marketplace', AppConfig.enableMarketplace);
  bool get aiAnalysis => _flag('ai_analysis', AppConfig.enableAiAnalysis);
  bool get advancedStats =>
      _flag('advanced_stats', AppConfig.enableAdvancedStats);
  bool get communityContests =>
      _flag('community_contests', AppConfig.enableCommunityContests);
  bool get seasonalLeaderboards =>
      _flag('seasonal_leaderboards', AppConfig.enableSeasonalLeaderboards);
  bool get deepLinking => _flag('deep_linking', AppConfig.enableDeepLinking);

  // ── Global Launch Features ──

  bool get featuredEvents =>
      _flag('featured_events', AppConfig.enableFeaturedEvents);
  bool get globalChallenges =>
      _flag('global_challenges', AppConfig.enableGlobalChallenges);
  bool get regionDiscovery =>
      _flag('region_discovery', AppConfig.enableRegionDiscovery);

  /// Check any flag by name (for dynamic/generic use).
  bool isEnabled(String key, {bool defaultValue = false}) =>
      _flag(key, defaultValue);
}

/// Riverpod provider for typed feature flags.
///
/// This gives a compile-safe API while allowing runtime overrides from the DB.
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags(ref.watch(bootstrapConfigProvider));
});
