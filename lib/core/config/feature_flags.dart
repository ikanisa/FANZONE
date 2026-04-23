/// Runtime feature flags service sourced from Supabase bootstrap data.
///
/// Usage:
///   ```dart
///   final flags = ref.read(featureFlagsProvider);
///   if (flags.predictions) { ... }
///   ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/bootstrap_config.dart';
import '../di/gateway_providers.dart';

class FeatureFlags {
  const FeatureFlags(this._bootstrapConfig);

  final BootstrapConfig _bootstrapConfig;

  bool _flag(String key) => _bootstrapConfig.featureFlags[key] == true;

  // ── Core Features ──

  bool get predictions => _flag('predictions');
  bool get wallet => _flag('wallet');
  bool get leaderboard => _flag('leaderboard');
  bool get rewards => _flag('rewards');
  bool get notifications => _flag('notifications');

  // ── Platform Features ──

  bool get deepLinking => _flag('deep_linking');

  // ── Global Launch Features ──

  bool get featuredEvents => _flag('featured_events');
  bool get regionDiscovery => _flag('region_discovery');

  /// Check any flag by name (for dynamic/generic use).
  bool isEnabled(String key) => _flag(key);
}

/// Riverpod provider for typed feature flags.
///
/// This gives a compile-safe API backed by the Supabase runtime bootstrap.
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags(ref.watch(bootstrapConfigProvider));
});
