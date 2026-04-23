library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap_config.dart';
import '../di/gateway_providers.dart';

enum PlatformSurface { navigation, home, route, action }

class PlatformFeatureAccess {
  const PlatformFeatureAccess(this._config, {required this.channel});

  final BootstrapConfig _config;
  final String channel;

  static const Map<String, Map<String, Object?>> _legacyFallback = {
    'home_feed': {
      'visible': true,
      'navigation': true,
      'home': true,
      'route': '/',
      'sort_order': 10,
      'label': 'Home',
    },
    'fixtures': {
      'visible': true,
      'navigation': true,
      'home': true,
      'route': '/fixtures',
      'sort_order': 20,
      'label': 'Fixtures',
    },
    'predictions': {
      'visible': true,
      'navigation': true,
      'home': true,
      'route': '/predict',
      'sort_order': 30,
      'label': 'Predict',
    },
    'leaderboard': {
      'visible': true,
      'navigation': false,
      'home': false,
      'route': '/leaderboard',
      'sort_order': 40,
      'label': 'Leaderboard',
    },
    'wallet': {
      'visible': true,
      'navigation': false,
      'home': false,
      'route': '/wallet',
      'sort_order': 50,
      'label': 'Wallet',
    },
    'profile': {
      'visible': true,
      'navigation': true,
      'home': false,
      'route': '/profile',
      'sort_order': 60,
      'label': 'Profile',
    },
    'notifications': {
      'visible': true,
      'navigation': false,
      'home': false,
      'route': '/notifications',
      'sort_order': 70,
      'label': 'Notifications',
    },
    'settings': {
      'visible': true,
      'navigation': false,
      'home': false,
      'route': '/settings',
      'sort_order': 80,
      'label': 'Settings',
    },
    'match_center': {
      'visible': true,
      'navigation': false,
      'home': false,
      'route': '/match/:matchId',
      'sort_order': 90,
      'label': 'Match Center',
    },
  };

  PlatformFeatureInfo? feature(String key) => _config.platformFeature(key);

  bool isVisible(
    String key, {
    PlatformSurface surface = PlatformSurface.route,
  }) {
    final feature = _config.platformFeature(key);
    if (feature != null) {
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

    final fallback = _legacyFallback[key];
    if (fallback == null) {
      return _config.isFeatureEnabled(key, defaultValue: false);
    }

    final enabled = _config.isFeatureEnabled(key, defaultValue: true);
    if (!enabled) return false;

    switch (surface) {
      case PlatformSurface.navigation:
        return fallback['navigation'] == true;
      case PlatformSurface.home:
        return fallback['home'] == true;
      case PlatformSurface.route:
      case PlatformSurface.action:
        return fallback['visible'] == true;
    }
  }

  String routeFor(String key) {
    final feature = _config.platformFeature(key);
    if (feature != null) {
      final channelConfig = feature.channel(channel);
      return channelConfig.routeKey ??
          feature.resolvedState.routeKey ??
          feature.defaultRouteKey ??
          (_legacyFallback[key]?['route'] as String? ?? '/');
    }
    return _legacyFallback[key]?['route'] as String? ?? '/';
  }

  String labelFor(String key) {
    final feature = _config.platformFeature(key);
    if (feature != null) {
      final channelConfig = feature.channel(channel);
      return channelConfig.navigationLabel ?? feature.displayName;
    }
    return _legacyFallback[key]?['label'] as String? ?? key;
  }

  int sortOrderFor(String key) {
    final feature = _config.platformFeature(key);
    if (feature != null) {
      return feature.channel(channel).sortOrder;
    }
    return _legacyFallback[key]?['sort_order'] as int? ?? 100;
  }

  List<PlatformFeatureInfo> navigationFeatures() {
    final registered =
        _config.platformFeatures
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

    if (registered.isNotEmpty) {
      return registered;
    }

    return _legacyFallback.keys
        .where((key) => isVisible(key, surface: PlatformSurface.navigation))
        .map((key) {
          return PlatformFeatureInfo.fromJson({
            'feature_key': key,
            'display_name': labelFor(key),
            'is_enabled': true,
            'channels': {
              channel: {
                'channel': channel,
                'is_visible': true,
                'is_enabled': true,
                'show_in_navigation': true,
                'show_on_home': _legacyFallback[key]?['home'] == true,
                'sort_order': sortOrderFor(key),
                'route_key': routeFor(key),
                'navigation_label': labelFor(key),
              },
            },
            'resolved_state': {
              'is_operational': true,
              'is_visible': true,
              'is_available': true,
              'show_in_navigation': true,
              'show_on_home': _legacyFallback[key]?['home'] == true,
              'route_key': routeFor(key),
              'sort_order': sortOrderFor(key),
            },
          });
        })
        .toList(growable: false);
  }

  List<PlatformContentBlockInfo> homeBlocks({
    String placementKey = 'home.primary',
  }) {
    final blocks =
        _config
            .contentBlocksForChannel(channel, placementKey: placementKey)
            .where((block) {
              if (block.featureKey == null || block.featureKey!.isEmpty)
                return true;
              return isVisible(
                block.featureKey!,
                surface: PlatformSurface.home,
              );
            })
            .toList(growable: false)
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

    if (blocks.isNotEmpty) return blocks;

    return [
      PlatformContentBlockInfo.fromJson({
        'block_key': 'home_promo_banner',
        'block_type': 'promo_banner',
        'title': 'Lean Matchday Window',
        'content': {
          'badge': 'DERBY DAY',
          'kicker': 'GLOBAL',
          'subtitle': 'Fresh free picks are live now.',
          'cta_label': 'OPEN PICKS',
          'cta_route': '/predict',
        },
        'target_channel': channel,
        'is_active': true,
        'sort_order': 10,
        'feature_key': 'predictions',
        'placement_key': placementKey,
      }),
      PlatformContentBlockInfo.fromJson({
        'block_key': 'home_daily_insight',
        'block_type': 'daily_insight',
        'title': 'Daily Insight',
        'content': {
          'subtitle':
              'The home feed now focuses on live fixtures, upcoming picks, and leaderboard progress.',
        },
        'target_channel': channel,
        'is_active': true,
        'sort_order': 15,
        'feature_key': 'predictions',
        'placement_key': placementKey,
      }),
      PlatformContentBlockInfo.fromJson({
        'block_key': 'home_live_matches',
        'block_type': 'live_matches',
        'title': 'Live Action',
        'content': {
          'empty_title': 'No Live Matches',
          'empty_description': 'Check upcoming.',
        },
        'target_channel': channel,
        'is_active': true,
        'sort_order': 20,
        'feature_key': 'fixtures',
        'placement_key': placementKey,
      }),
      PlatformContentBlockInfo.fromJson({
        'block_key': 'home_upcoming_matches',
        'block_type': 'upcoming_matches',
        'title': 'Upcoming',
        'content': {
          'empty_title': 'No Upcoming',
          'empty_description': 'None left.',
          'cta_route': '/fixtures',
        },
        'target_channel': channel,
        'is_active': true,
        'sort_order': 30,
        'feature_key': 'fixtures',
        'placement_key': placementKey,
      }),
    ];
  }
}

final platformFeatureAccessProvider = Provider<PlatformFeatureAccess>((ref) {
  final channel = kIsWeb ? 'web' : 'mobile';
  return PlatformFeatureAccess(
    ref.watch(bootstrapConfigProvider),
    channel: channel,
  );
});
