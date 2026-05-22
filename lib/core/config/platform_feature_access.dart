library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/runtime_auth_session_manager.dart';
import '../di/gateway_providers.dart';
import 'bootstrap_config.dart';
import 'runtime_bootstrap.dart';

enum PlatformSurface { navigation, home, route, action }

const _guestFeatureKeys = {
  'home',
  'match_center',
  'pools',
  'ordering',
  'venues',
  'wallet',
  'profile',
  'notifications',
  'settings',
  'rewards',
};

class PlatformFeatureAccess {
  const PlatformFeatureAccess(this._config, {required this.channel});

  final BootstrapConfig _config;
  final String channel;

  PlatformFeatureInfo? feature(String key) => _config.platformFeature(key);

  bool isActionAvailable(String key, {required bool isAuthenticated}) {
    final configuredFeature = _config.platformFeature(key);
    if (configuredFeature == null) {
      return false;
    }

    final state = configuredFeature.resolvedState;
    if (!state.isOperational || !state.isAvailable) {
      return false;
    }

    if (configuredFeature.authRequired && !isAuthenticated) {
      return false;
    }

    return true;
  }

  bool isVisible(
    String key, {
    PlatformSurface surface = PlatformSurface.route,
  }) {
    if (!_guestFeatureKeys.contains(key)) {
      return false;
    }

    final feature = this.feature(key);
    if (feature == null) {
      return false;
    }

    final state = feature.resolvedState;
    if (!state.isOperational || !state.isVisible) {
      return false;
    }

    switch (surface) {
      case PlatformSurface.navigation:
        return state.showInNavigation;
      case PlatformSurface.home:
        return state.showOnHome;
      case PlatformSurface.route:
      case PlatformSurface.action:
        return true;
    }
  }

  String routeFor(String key) {
    final feature = this.feature(key);
    final channelConfig = feature?.channel(channel);
    return channelConfig?.routeKey ??
        feature?.resolvedState.routeKey ??
        feature?.defaultRouteKey ??
        '/';
  }

  String labelFor(String key) {
    final feature = this.feature(key);
    final channelConfig = feature?.channel(channel);
    return channelConfig?.navigationLabel ?? feature?.displayName ?? key;
  }

  String? routeKeyForPath(String path) {
    final normalizedPath = _pathOnly(path);
    for (final feature in _config.platformFeatures) {
      final featureRoute =
          feature.channel(channel).routeKey ??
          feature.resolvedState.routeKey ??
          feature.defaultRouteKey;
      if (featureRoute != null && _routeMatches(featureRoute, normalizedPath)) {
        return feature.featureKey;
      }
    }
    return null;
  }

  List<PlatformFeatureInfo> visibleFeatures({
    PlatformSurface surface = PlatformSurface.route,
  }) {
    return _config.platformFeatures
        .where((f) => isVisible(f.featureKey, surface: surface))
        .toList();
  }

  int sortOrderFor(String key) {
    final feature = this.feature(key);
    return feature?.channel(channel).sortOrder ?? 100;
  }

  List<PlatformFeatureInfo> navigationFeatures() {
    return _config.platformFeatures
        .where(
          (feature) => isVisible(
            feature.featureKey,
            surface: PlatformSurface.navigation,
          ),
        )
        .toList(growable: false)
      ..sort(
        (left, right) => left
            .channel(channel)
            .sortOrder
            .compareTo(right.channel(channel).sortOrder),
      );
  }

  List<PlatformContentBlockInfo> homeBlocks({
    String placementKey = 'home.primary',
  }) {
    return _config
        .contentBlocksForChannel(channel, placementKey: placementKey)
        .where((block) {
          if (block.featureKey == null || block.featureKey!.isEmpty) {
            return true;
          }

          return isVisible(block.featureKey!, surface: PlatformSurface.home);
        })
        .toList(growable: false)
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  }
}

String _pathOnly(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '/';

  final parsed = Uri.tryParse(trimmed);
  final parsedPath = parsed?.path;
  if (parsedPath != null && parsedPath.isNotEmpty) return parsedPath;

  final queryStart = trimmed.indexOf('?');
  return queryStart == -1 ? trimmed : trimmed.substring(0, queryStart);
}

bool _routeMatches(String routeTemplate, String path) {
  final templateSegments = _pathSegments(routeTemplate);
  final pathSegments = _pathSegments(path);
  if (templateSegments.isEmpty) return pathSegments.isEmpty;
  if (templateSegments.length > pathSegments.length) return false;

  for (var index = 0; index < templateSegments.length; index++) {
    final templateSegment = templateSegments[index];
    if (templateSegment.startsWith(':')) continue;
    if (templateSegment != pathSegments[index]) return false;
  }

  return true;
}

List<String> _pathSegments(String path) {
  return path
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
}

final platformFeatureAccessProvider = Provider<PlatformFeatureAccess>((ref) {
  const channel = kIsWeb ? 'web' : 'mobile';
  return PlatformFeatureAccess(
    ref.watch(bootstrapConfigProvider),
    channel: channel,
  );
});

PlatformFeatureAccess runtimePlatformFeatureAccess({String? channel}) {
  return PlatformFeatureAccess(
    runtimeBootstrapStore.config,
    channel: channel ?? (kIsWeb ? 'web' : 'mobile'),
  );
}

bool runtimePlatformFeatureActionAvailable(String key, {String? channel}) {
  final session = RuntimeAuthSessionManager.instance.currentSession;
  final isAuthenticated = session != null && !session.isExpired;
  return runtimePlatformFeatureAccess(
    channel: channel,
  ).isActionAvailable(key, isAuthenticated: isAuthenticated);
}

void assertRuntimePlatformFeatureActionAvailable(
  String key, {
  String? channel,
  String? fallbackMessage,
}) {
  if (runtimePlatformFeatureActionAvailable(key, channel: channel)) {
    return;
  }

  final access = runtimePlatformFeatureAccess(channel: channel);
  throw StateError(
    fallbackMessage ?? '${access.labelFor(key)} is currently unavailable.',
  );
}
